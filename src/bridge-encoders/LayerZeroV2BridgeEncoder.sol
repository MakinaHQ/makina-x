// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IBridgeComponent} from "../interfaces/IBridgeComponent.sol";
import {IBridgeEncoder} from "../interfaces/IBridgeEncoder.sol";
import {ILayerZeroV2BridgeEncoder} from "../interfaces/ILayerZeroV2BridgeEncoder.sol";
import {IOFT} from "../interfaces/IOFT.sol";
import {Errors} from "../libraries/Errors.sol";

contract LayerZeroV2BridgeEncoder is AccessManagedUpgradeable, ILayerZeroV2BridgeEncoder {
    // Packed prefix: TYPE_3 | WORKER_ID | OPTION LENGTH | OPTION_TYPE_LZRECEIVE
    // = 0x0003 | 0x01 | 0x0011 | 0x01
    bytes6 internal constant EXECUTOR_LZRECEIVE_PREFIX = 0x000301001101;

    /// @custom:storage-location erc7201:makina.storage.LayerZeroV2BridgeEncoder
    struct LayerZeroV2BridgeEncoderStorage {
        mapping(uint256 evmChainId => uint32 lzEndpointId) _evmToLzId;
        mapping(uint32 lzEndpointId => uint256 evmChainId) _lzToEvmId;
        mapping(address oft => bool isRegistered) _isOftRegistered;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.LayerZeroV2BridgeEncoder")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LayerZeroV2BridgeEncoderStorageLocation =
        0xecd8981fd5d1fee10c72726d865a16a974a3b620f0b56ff7bc8172fd1d9bcb00;

    function _getLayerZeroV2BridgeEncoderStorage() private pure returns (LayerZeroV2BridgeEncoderStorage storage $) {
        assembly {
            $.slot := LayerZeroV2BridgeEncoderStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function getLzEndpointId(uint256 evmChainId) public view override returns (uint32) {
        uint32 eid = _getLayerZeroV2BridgeEncoderStorage()._evmToLzId[evmChainId];
        if (eid == 0) {
            revert Errors.LzEndpointIdNotRegistered();
        }
        return eid;
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function isOftRegistered(address oft) public view override returns (bool) {
        return _getLayerZeroV2BridgeEncoderStorage()._isOftRegistered[oft];
    }

    /// @inheritdoc IBridgeEncoder
    function getBridgeTransferData(IBridgeComponent.BridgeOrder calldata order, bool lockdownMode)
        external
        view
        override
        returns (address, address, uint256, bytes memory)
    {
        (address oft, uint128 lzReceiveGas, uint256 maxValue) = abi.decode(order.extraData, (address, uint128, uint256));
        if (lockdownMode && !_getLayerZeroV2BridgeEncoderStorage()._isOftRegistered[oft]) {
            revert Errors.OftNotRegistered();
        }

        if (oft == address(0) || IOFT(oft).token() != order.inputToken) {
            revert Errors.OftMismatch();
        }

        bytes memory options;
        if (lzReceiveGas != 0) {
            options = _getLzReceiveOption(lzReceiveGas);
        } else {
            options = "";
        }

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: getLzEndpointId(order.destinationChainId),
            to: bytes32(uint256(uint160(order.recipient))),
            amountLD: order.inputAmount,
            minAmountLD: order.minOutputAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        IOFT.MessagingFee memory mf = IOFT(oft).quoteSend(sendParam, false);
        if (mf.nativeFee > maxValue) {
            revert Errors.ExceededMaxFee(mf.nativeFee, maxValue);
        }

        (,, IOFT.OFTReceipt memory oftr) = IOFT(oft).quoteOFT(sendParam);
        if (oftr.amountSentLD != order.inputAmount) {
            revert Errors.InvalidLzSentAmount();
        }
        if (oftr.amountReceivedLD < order.minOutputAmount) {
            revert Errors.AmountOutTooLow();
        }

        bytes memory cd = abi.encodeCall(IOFT.send, (sendParam, mf, msg.sender)); // solhint-disable-line check-send-result

        address approvalTarget;
        if (IOFT(oft).approvalRequired()) {
            approvalTarget = oft;
        }

        return (approvalTarget, oft, mf.nativeFee, cd);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function setLzEndpointId(uint256 evmChainId, uint32 lzEndpointId) external override restricted {
        LayerZeroV2BridgeEncoderStorage storage $ = _getLayerZeroV2BridgeEncoderStorage();

        if (evmChainId == 0) {
            revert Errors.ZeroChainId();
        }

        if (lzEndpointId == 0) {
            revert Errors.ZeroLzEndpointId();
        }

        uint32 oldLz = $._evmToLzId[evmChainId];
        if (oldLz != 0) {
            delete $._lzToEvmId[oldLz];
        }

        uint256 oldEvm = $._lzToEvmId[lzEndpointId];
        if (oldEvm != 0) {
            delete $._evmToLzId[oldEvm];
        }

        $._evmToLzId[evmChainId] = lzEndpointId;
        $._lzToEvmId[lzEndpointId] = evmChainId;
        emit LzEndpointIdRegistered(evmChainId, lzEndpointId);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function addOft(address oft) external override restricted {
        LayerZeroV2BridgeEncoderStorage storage $ = _getLayerZeroV2BridgeEncoderStorage();

        if (oft == address(0)) {
            revert Errors.ZeroAddress();
        }

        if ($._isOftRegistered[oft]) {
            revert Errors.OftAlreadyRegistered();
        }
        $._isOftRegistered[oft] = true;

        emit OftAdded(oft);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function removeOft(address oft) external override restricted {
        LayerZeroV2BridgeEncoderStorage storage $ = _getLayerZeroV2BridgeEncoderStorage();

        if (oft == address(0)) {
            revert Errors.ZeroAddress();
        }

        if (!$._isOftRegistered[oft]) {
            revert Errors.OftNotRegistered();
        }
        $._isOftRegistered[oft] = false;

        emit OftRemoved(oft);
    }

    /// @dev Internal logic to craft lzReceive option.
    function _getLzReceiveOption(uint128 _lzReceiveGas) internal pure returns (bytes memory) {
        return abi.encodePacked(EXECUTOR_LZRECEIVE_PREFIX, _lzReceiveGas);
    }
}

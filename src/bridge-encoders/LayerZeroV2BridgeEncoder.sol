// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IBridgeComponent} from "../interfaces/IBridgeComponent.sol";
import {IBridgeEncoder} from "../interfaces/IBridgeEncoder.sol";
import {ILayerZeroV2BridgeEncoder} from "../interfaces/ILayerZeroV2BridgeEncoder.sol";
import {IMakinaLiteGovernable} from "../interfaces/IMakinaLiteGovernable.sol";
import {IOFT} from "../interfaces/IOFT.sol";
import {Errors} from "../libraries/Errors.sol";

contract LayerZeroV2BridgeEncoder layout at erc7201("makina.storage.LayerZeroV2BridgeEncoder")
    is
    AccessManagedUpgradeable,
    ILayerZeroV2BridgeEncoder
{
    // Packed prefix: TYPE_3 | WORKER_ID | OPTION LENGTH | OPTION_TYPE_LZRECEIVE
    // = 0x0003 | 0x01 | 0x0011 | 0x01
    bytes6 internal constant EXECUTOR_LZRECEIVE_PREFIX = 0x000301001101;

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    mapping(address oft => bool isRegistered) public isOftRegistered;

    mapping(uint256 evmChainId => uint32 lzEndpointId) private _evmToLzId;
    mapping(uint32 lzEndpointId => uint256 evmChainId) private _lzToEvmId;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function getLzEndpointId(uint256 evmChainId) public view override returns (uint32) {
        uint32 eid = _evmToLzId[evmChainId];
        if (eid == 0) {
            revert Errors.LzEndpointIdNotRegistered();
        }
        return eid;
    }

    /// @inheritdoc IBridgeEncoder
    function getBridgeTransferData(IBridgeComponent.BridgeOrder calldata order)
        external
        view
        override
        returns (address, address, uint256, bytes memory)
    {
        (address oft, uint128 lzReceiveGas, uint256 maxValue) = abi.decode(order.extraData, (address, uint128, uint256));

        address caller = msg.sender;
        if (IMakinaLiteGovernable(caller).lockdownMode() && !isOftRegistered[oft]) {
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

        bytes memory cd = abi.encodeCall(IOFT.send, (sendParam, mf, caller)); // solhint-disable-line check-send-result

        address approvalTarget;
        if (IOFT(oft).approvalRequired()) {
            approvalTarget = oft;
        }

        return (approvalTarget, oft, mf.nativeFee, cd);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function setLzEndpointId(uint256 evmChainId, uint32 lzEndpointId) external override restricted {
        if (evmChainId == 0) {
            revert Errors.ZeroChainId();
        }

        if (lzEndpointId == 0) {
            revert Errors.ZeroLzEndpointId();
        }

        uint32 oldLz = _evmToLzId[evmChainId];
        if (oldLz != 0) {
            delete _lzToEvmId[oldLz];
        }

        uint256 oldEvm = _lzToEvmId[lzEndpointId];
        if (oldEvm != 0) {
            delete _evmToLzId[oldEvm];
        }

        _evmToLzId[evmChainId] = lzEndpointId;
        _lzToEvmId[lzEndpointId] = evmChainId;
        emit LzEndpointIdRegistered(evmChainId, lzEndpointId);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function addOft(address oft) external override restricted {
        if (oft == address(0)) {
            revert Errors.ZeroAddress();
        }

        if (isOftRegistered[oft]) {
            revert Errors.OftAlreadyRegistered();
        }
        isOftRegistered[oft] = true;

        emit OftAdded(oft);
    }

    /// @inheritdoc ILayerZeroV2BridgeEncoder
    function removeOft(address oft) external override restricted {
        if (oft == address(0)) {
            revert Errors.ZeroAddress();
        }

        if (!isOftRegistered[oft]) {
            revert Errors.OftNotRegistered();
        }
        isOftRegistered[oft] = false;

        emit OftRemoved(oft);
    }

    /// @dev Internal logic to craft lzReceive option.
    function _getLzReceiveOption(uint128 _lzReceiveGas) internal pure returns (bytes memory) {
        return abi.encodePacked(EXECUTOR_LZRECEIVE_PREFIX, _lzReceiveGas);
    }
}

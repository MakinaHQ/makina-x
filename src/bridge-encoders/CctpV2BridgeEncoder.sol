// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IBridgeComponent} from "../interfaces/IBridgeComponent.sol";
import {IBridgeEncoder} from "../interfaces/IBridgeEncoder.sol";
import {ICctpV2BridgeEncoder} from "../interfaces/ICctpV2BridgeEncoder.sol";
import {ICctpV2TokenMessenger} from "../interfaces/ICctpV2TokenMessenger.sol";
import {Errors} from "../libraries/Errors.sol";

contract CctpV2BridgeEncoder is AccessManagedUpgradeable, ICctpV2BridgeEncoder {
    using Math for uint256;

    uint256 private constant MAINNET_CHAIN_ID = 1;
    uint32 private constant MAINNET_CCTP_DOMAIN = 0;

    // Packed magic bytes ("cctp-forward") + hook version (0) + empty data length (0)
    bytes private constant FORWARD_HOOK_DATA = hex"636374702d666f72776172640000000000000000000000000000000000000000";

    /// @inheritdoc ICctpV2BridgeEncoder
    address public immutable cctpV2TokenMessenger;

    /// @custom:storage-location erc7201:makina.storage.CctpV2BridgeEncoder
    struct CctpV2BridgeEncoderStorage {
        mapping(uint256 evmChainId => uint32 cctpDomain) _evmToCctpId;
        mapping(uint32 cctpDomain => uint256 evmChainId) _cctpToEvmId;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CctpV2BridgeEncoder")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CctpV2BridgeEncoderStorageLocation =
        0xf328330f3f10dab15d2017eb5a9b8f097a1f885a67bf8c1c3d0c92f22ff92700;

    function _getCctpV2BridgeEncoderStorage() private pure returns (CctpV2BridgeEncoderStorage storage $) {
        assembly {
            $.slot := CctpV2BridgeEncoderStorageLocation
        }
    }

    constructor(address _cctpV2TokenMessenger) {
        cctpV2TokenMessenger = _cctpV2TokenMessenger;
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        emit CctpDomainRegistered(MAINNET_CHAIN_ID, MAINNET_CCTP_DOMAIN);

        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc ICctpV2BridgeEncoder
    function getCctpDomain(uint256 evmChainId) public view override returns (uint32) {
        if (evmChainId == MAINNET_CHAIN_ID) {
            return MAINNET_CCTP_DOMAIN;
        }
        uint32 cctpDomain = _getCctpV2BridgeEncoderStorage()._evmToCctpId[evmChainId];
        if (cctpDomain == 0) {
            revert Errors.CctpDomainNotRegistered();
        }
        return cctpDomain;
    }

    /// @inheritdoc IBridgeEncoder
    function getBridgeTransferData(IBridgeComponent.BridgeOrder calldata order, bool)
        external
        view
        override
        returns (address, address, uint256, bytes memory)
    {
        uint32 destCctpDomain = getCctpDomain(order.destinationChainId);

        if (order.minOutputAmount > order.inputAmount) {
            revert Errors.MinOutputAmountExceedsInputAmount();
        }

        (uint32 minFinalityThreshold) = abi.decode(order.extraData, (uint32));

        bytes32 recipient = bytes32(uint256(uint160(order.recipient)));
        bytes memory cd = abi.encodeCall(
            ICctpV2TokenMessenger.depositForBurnWithHook,
            (
                order.inputAmount,
                destCctpDomain,
                recipient,
                order.inputToken,
                bytes32(0),
                order.inputAmount - order.minOutputAmount,
                minFinalityThreshold,
                FORWARD_HOOK_DATA
            )
        );

        return (cctpV2TokenMessenger, cctpV2TokenMessenger, 0, cd);
    }

    /// @inheritdoc ICctpV2BridgeEncoder
    function setCctpDomain(uint256 evmChainId, uint32 cctpDomain) external override restricted {
        CctpV2BridgeEncoderStorage storage $ = _getCctpV2BridgeEncoderStorage();

        if (evmChainId == 0) {
            revert Errors.ZeroChainId();
        }
        if (evmChainId == MAINNET_CHAIN_ID) {
            revert Errors.ProtectedChainId();
        }
        if (cctpDomain == MAINNET_CCTP_DOMAIN) {
            revert Errors.ProtectedCctpDomain();
        }

        uint32 oldDomain = $._evmToCctpId[evmChainId];
        if (oldDomain != 0) {
            delete $._cctpToEvmId[oldDomain];
        }

        uint256 oldEvmChainId = $._cctpToEvmId[cctpDomain];
        if (oldEvmChainId != 0) {
            delete $._evmToCctpId[oldEvmChainId];
        }

        $._evmToCctpId[evmChainId] = cctpDomain;
        $._cctpToEvmId[cctpDomain] = evmChainId;
        emit CctpDomainRegistered(evmChainId, cctpDomain);
    }
}

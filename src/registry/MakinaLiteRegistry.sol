// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IMakinaLiteRegistry} from "../interfaces/IMakinaLiteRegistry.sol";
import {Errors} from "../libraries/Errors.sol";

contract MakinaLiteRegistry is AccessManagedUpgradeable, IMakinaLiteRegistry {
    /// @custom:storage-location erc7201:makina.storage.MakinaLiteRegistry
    struct MakinaLiteRegistryStorage {
        address _moduleFactory;
        address _moduleImplementation;
        address _feeCollector;
        address _flashLoanModule;
        mapping(uint16 bridgeId => address encoder) _bridgeEncoders;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.MakinaLiteRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MakinaLiteRegistryStorageLocation =
        0xef78750e7ffffd9087e6b5da2ceae6958dbfa00caaf5353b49cdf645f9a1dc00;

    function _getMakinaLiteRegistryStorage() private pure returns (MakinaLiteRegistryStorage storage $) {
        assembly {
            $.slot := MakinaLiteRegistryStorageLocation
        }
    }

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc IMakinaLiteRegistry
    function moduleFactory() external view returns (address) {
        return _getMakinaLiteRegistryStorage()._moduleFactory;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function moduleImplementation() external view returns (address) {
        return _getMakinaLiteRegistryStorage()._moduleImplementation;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function feeCollector() external view override returns (address) {
        return _getMakinaLiteRegistryStorage()._feeCollector;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function flashLoanModule() external view override returns (address) {
        return _getMakinaLiteRegistryStorage()._flashLoanModule;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function getBridgeEncoder(uint16 bridgeId) external view returns (address) {
        address encoder = _getMakinaLiteRegistryStorage()._bridgeEncoders[bridgeId];
        if (encoder == address(0)) {
            revert Errors.BridgeEncoderDoesNotExist();
        }
        return encoder;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function setModuleFactory(address factory) external restricted {
        MakinaLiteRegistryStorage storage $ = _getMakinaLiteRegistryStorage();
        emit ModuleFactoryChanged($._moduleFactory, factory);
        $._moduleFactory = factory;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function setModuleImplementation(address newImplementation) external restricted {
        MakinaLiteRegistryStorage storage $ = _getMakinaLiteRegistryStorage();
        emit ModuleImplementationChanged($._moduleImplementation, newImplementation);
        $._moduleImplementation = newImplementation;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function setFeeCollector(address newFeeCollector) external restricted {
        MakinaLiteRegistryStorage storage $ = _getMakinaLiteRegistryStorage();
        emit FeeCollectorChanged($._feeCollector, newFeeCollector);
        $._feeCollector = newFeeCollector;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function setFlashLoanModule(address newFlashLoanModule) external restricted {
        MakinaLiteRegistryStorage storage $ = _getMakinaLiteRegistryStorage();
        emit FlashLoanModuleChanged($._flashLoanModule, newFlashLoanModule);
        $._flashLoanModule = newFlashLoanModule;
    }

    /// @inheritdoc IMakinaLiteRegistry
    function setBridgeEncoder(uint16 bridgeId, address bridgeEncoder) external restricted {
        MakinaLiteRegistryStorage storage $ = _getMakinaLiteRegistryStorage();
        emit BridgeEncoderChanged(bridgeId, $._bridgeEncoders[bridgeId], bridgeEncoder);
        $._bridgeEncoders[bridgeId] = bridgeEncoder;
    }
}

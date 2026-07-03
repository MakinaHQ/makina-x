// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IMakinaXRegistry} from "../interfaces/IMakinaXRegistry.sol";
import {Errors} from "../libraries/Errors.sol";

contract MakinaXRegistry layout at erc7201("makina.storage.MakinaXRegistry")
    is
    AccessManagedUpgradeable,
    IMakinaXRegistry
{
    /// @inheritdoc IMakinaXRegistry
    address public moduleFactory;

    /// @inheritdoc IMakinaXRegistry
    address public moduleImplementation;

    /// @inheritdoc IMakinaXRegistry
    address public feeCollector;

    /// @inheritdoc IMakinaXRegistry
    address public flashLoanModule;

    mapping(uint16 bridgeId => address encoder) private _bridgeEncoders;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc IMakinaXRegistry
    function getBridgeEncoder(uint16 bridgeId) external view returns (address) {
        address encoder = _bridgeEncoders[bridgeId];
        if (encoder == address(0)) {
            revert Errors.BridgeEncoderDoesNotExist();
        }
        return encoder;
    }

    /// @inheritdoc IMakinaXRegistry
    function setModuleFactory(address newModuleFactory) external restricted {
        emit ModuleFactoryChanged(moduleFactory, newModuleFactory);
        moduleFactory = newModuleFactory;
    }

    /// @inheritdoc IMakinaXRegistry
    function setModuleImplementation(address newImplementation) external restricted {
        emit ModuleImplementationChanged(moduleImplementation, newImplementation);
        moduleImplementation = newImplementation;
    }

    /// @inheritdoc IMakinaXRegistry
    function setFeeCollector(address newFeeCollector) external restricted {
        emit FeeCollectorChanged(feeCollector, newFeeCollector);
        feeCollector = newFeeCollector;
    }

    /// @inheritdoc IMakinaXRegistry
    function setFlashLoanModule(address newFlashLoanModule) external restricted {
        emit FlashLoanModuleChanged(flashLoanModule, newFlashLoanModule);
        flashLoanModule = newFlashLoanModule;
    }

    /// @inheritdoc IMakinaXRegistry
    function setBridgeEncoder(uint16 bridgeId, address bridgeEncoder) external restricted {
        emit BridgeEncoderChanged(bridgeId, _bridgeEncoders[bridgeId], bridgeEncoder);
        _bridgeEncoders[bridgeId] = bridgeEncoder;
    }
}

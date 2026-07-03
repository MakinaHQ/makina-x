// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMakinaXRegistry {
    event BridgeEncoderChanged(
        uint16 indexed bridgeId, address indexed oldBridgeEncoder, address indexed newBridgeEncoder
    );
    event FeeCollectorChanged(address indexed oldFeeCollector, address indexed newFeeCollector);
    event FlashLoanModuleChanged(address indexed oldFlashLoanModule, address indexed newFlashLoanModule);
    event ModuleFactoryChanged(address indexed oldModuleFactory, address indexed newModuleFactory);
    event ModuleImplementationChanged(address indexed oldModuleImplementation, address indexed newModuleImplementation);

    /// @notice Address of the MakinaXModule factory.
    function moduleFactory() external view returns (address);

    /// @notice Address of the MakinaXModule implementation.
    function moduleImplementation() external view returns (address);

    /// @notice Address of the fee collector.
    function feeCollector() external view returns (address);

    /// @notice Address of the flash loan module.
    function flashLoanModule() external view returns (address);

    /// @notice Bridge ID => Address of the corresponding bridge encoder.
    function getBridgeEncoder(uint16 bridgeId) external view returns (address);

    /// @notice Sets the address of the MakinaXModule factory.
    /// @param newModuleFactory The address of the new MakinaXModule factory.
    function setModuleFactory(address newModuleFactory) external;

    /// @notice Sets the MakinaXModule implementation for future deployments.
    /// @param newImplementation The address of the new implementation contract.
    function setModuleImplementation(address newImplementation) external;

    /// @notice Sets the address of the fee collector.
    /// @param newFeeCollector The address of the new fee collector.
    function setFeeCollector(address newFeeCollector) external;

    /// @notice Sets the address of the flash loan module.
    /// @param newFlashLoanModule The address of the new flash loan module.
    function setFlashLoanModule(address newFlashLoanModule) external;

    /// @notice Sets a bridge encoder instance for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    /// @param bridgeEncoder The address of the new bridge encoder instance.
    function setBridgeEncoder(uint16 bridgeId, address bridgeEncoder) external;
}

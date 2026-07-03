// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMakinaXModule} from "./IMakinaXModule.sol";

interface IModuleFactory {
    event MakinaXModuleCreated(address indexed module, address indexed implementation, bytes32 indexed referralKey);
    event DefaultProviderChanged(address indexed oldDefaultProvider, address indexed newDefaultProvider);
    event DefaultSwapFeeRateChanged(uint256 oldDefaultSwapFeeRate, uint256 newDefaultSwapFeeRate);
    event FreeDeploymentChanged(bool enabled);

    /// @notice Module => Whether the module was deployed by this factory.
    function isMakinaXModule(address module) external view returns (bool);

    /// @notice Provider enforced by default on modules deployed through the free path.
    function defaultProvider() external view returns (address);

    /// @notice Swap fee rate enforced by default on modules deployed through the free path, 1e18 = 100%.
    function defaultSwapFeeRate() external view returns (uint256);

    /// @notice Whether free module deployment is currently enabled.
    function freeDeployment() external view returns (bool);

    /// @notice Deploys a new MakinaXModule clone with caller-provided service parameters.
    /// @dev Restricted to authorized deployers.
    /// @param params The strategy and risk initialization parameters for the MakinaXModule.
    /// @param serviceParams The protocol-controlled service initialization parameters.
    /// @param salt The salt used for deterministic deployment of the module clone.
    /// @param referralKey The referral key associated with the module creation.
    /// @return The address of the newly deployed MakinaXModule.
    function createModule(
        IMakinaXModule.MakinaXModuleInitParams calldata params,
        IMakinaXModule.MakinaXModuleServiceParams calldata serviceParams,
        bytes32 salt,
        bytes32 referralKey
    ) external returns (address);

    /// @notice Deploys a new MakinaXModule clone, with service parameters enforced by the factory.
    /// @dev Callable by anyone while free deployment is enabled.
    /// @param params The strategy and risk initialization parameters for the MakinaXModule.
    /// @param salt The caller-scoped salt used for deterministic deployment of the module clone.
    /// @param referralKey The referral key associated with the module creation.
    /// @return The address of the newly deployed MakinaXModule.
    function createModuleFree(IMakinaXModule.MakinaXModuleInitParams calldata params, bytes32 salt, bytes32 referralKey)
        external
        returns (address);

    /// @notice Sets the provider enforced on free deployment.
    /// @param newDefaultProvider The new default provider address.
    function setDefaultProvider(address newDefaultProvider) external;

    /// @notice Sets the swap fee rate enforced on free deployment.
    /// @param newDefaultSwapFeeRate The new default swap fee rate, 1e18 = 100%.
    function setDefaultSwapFeeRate(uint256 newDefaultSwapFeeRate) external;

    /// @notice Enables or disables free module deployment.
    /// @param enabled True to enable free deployment, false to disable it.
    function setFreeDeployment(bool enabled) external;
}

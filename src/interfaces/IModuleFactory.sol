// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IMakinaLiteModule} from "./IMakinaLiteModule.sol";

interface IModuleFactory {
    event MakinaLiteModuleCreated(address indexed module, address indexed implementation);

    /// @notice Module => Whether the module was deployed by this factory.
    function isMakinaLiteModule(address module) external view returns (bool);

    /// @notice Deploys a new MakinaLiteModule clone with the given parameters.
    /// @param params The initialization parameters for the MakinaLiteModule.
    /// @param salt The salt used for deterministic deployment of the module clone.
    /// @return The address of the newly deployed MakinaLiteModule.
    function createModule(IMakinaLiteModule.MakinaLiteModuleInitParams calldata params, bytes32 salt)
        external
        returns (address);
}

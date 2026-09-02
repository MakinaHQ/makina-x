// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXModule} from "../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {CreateModuleBase} from "./utils/CreateModuleBase.sol";

/// @notice Builds the `ModuleFactory.createModuleFree` call for a new MakinaXModule clone, with the service
///         parameters enforced by the factory, then broadcasts it or logs it.
/// @dev Callable by anyone while free deployment is enabled. Can also run in view mode
///      (`VIEW_MODE=true`) to log the calldata. See `CreateModuleBase` for modes and env vars.
contract CreateModuleFree is CreateModuleBase {
    function _createModuleCalldata(
        IMakinaXModule.MakinaXModuleInitParams memory params,
        bytes32 salt,
        bytes32 referralKey
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(ModuleFactory.createModuleFree, (params, salt, referralKey));
    }
}

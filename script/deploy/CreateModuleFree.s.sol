// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {CreateModuleBase} from "./base/CreateModuleBase.s.sol";

/// @notice Builds the `ModuleFactory.createModuleFree` call for a new MakinaXModule clone, with the service
///         parameters enforced by the factory, then broadcasts it or logs it.
/// @dev Callable by anyone while free deployment is enabled. Can also run in view mode
///      (`VIEW_MODE=true`) to log the calldata. See `CreateModuleBase` for modes and env vars.
contract CreateModuleFree is CreateModuleBase {
    function _createCall() internal view override returns (Call memory) {
        return Call({
            label: "ModuleFactory.createModuleFree",
            target: address(moduleFactory),
            data: abi.encodeCall(
                ModuleFactory.createModuleFree,
                (
                    _parseInitParams(),
                    vm.parseJsonBytes32(moduleInputJson, ".salt"),
                    vm.parseJsonBytes32(moduleInputJson, ".referralKey")
                )
            )
        });
    }
}

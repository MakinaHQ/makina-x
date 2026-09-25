// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXModule} from "../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {CreateModuleBase} from "./base/CreateModuleBase.s.sol";

/// @notice Builds the `ModuleFactory.createModule` call for a new MakinaXModule clone, with the service
///         parameters (provider and swap fee rate) read from the module input file, then broadcasts it or logs it.
/// @dev `createModule` is `restricted`: broadcast from an authorized account, or run in view mode
///      (`VIEW_MODE=true`) to log the calldata. See `CreateModuleBase` for modes and env vars.
contract CreateModule is CreateModuleBase {
    function _createCall() internal view override returns (Call memory) {
        return Call({
            label: "ModuleFactory.createModule",
            target: address(moduleFactory),
            data: abi.encodeCall(
                ModuleFactory.createModule,
                (
                    _parseInitParams(),
                    _parseServiceParams(),
                    vm.parseJsonBytes32(moduleInputJson, ".salt"),
                    vm.parseJsonBytes32(moduleInputJson, ".referralKey")
                )
            )
        });
    }

    function _parseServiceParams() internal view returns (IMakinaXModule.MakinaXModuleServiceParams memory) {
        return IMakinaXModule.MakinaXModuleServiceParams({
            initialProvider: vm.parseJsonAddress(moduleInputJson, ".initialProvider"),
            initialSwapFeeRate: vm.parseJsonUint(moduleInputJson, ".initialSwapFeeRate")
        });
    }
}

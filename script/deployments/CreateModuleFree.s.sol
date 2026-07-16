// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// console logging is used intentionally to expose factory call calldata in view mode
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IMakinaXGovernable} from "../../src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

/// @notice Deploys a single MakinaXModule clone through `ModuleFactory.createModuleFree`.
/// @dev Callable by anyone while free deployment is enabled on the ModuleFactory. Service parameters
///      (provider and swap fee rate) are enforced by the factory, and the provided salt is namespaced
///      by the broadcasting account.
///
/// Env vars:
///   INFRA_OUTPUT_FILENAME  - infra output file holding the ModuleFactory address
///                            (under script/deployments/outputs/makina-x-infra/)
///   MODULE_INPUT_FILENAME  - module init params input file
///                            (under script/deployments/inputs/makina-x-modules/)
///   MODULE_OUTPUT_FILENAME - file to write the deployed module address to
///                            (under script/deployments/outputs/makina-x-modules/, unused when VIEW_MODE is true)
///   VIEW_MODE (optional)   - if true, logs the ModuleFactory call calldata instead of deploying
///   TEST_SENDER (optional) - account to broadcast from
contract CreateModuleFree is Script {
    using stdJson for string;

    string public infraOutputJson;
    string public moduleInputJson;
    string public moduleOutputPath;

    bool public viewMode;

    address public module;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load ModuleFactory address from the infra output file
        string memory infraOutputPath = string.concat(basePath, "outputs/makina-x-infra/");
        infraOutputPath = string.concat(infraOutputPath, vm.envString("INFRA_OUTPUT_FILENAME"));
        infraOutputJson = vm.readFile(infraOutputPath);

        // load module init params
        string memory moduleInputPath = string.concat(basePath, "inputs/makina-x-modules/");
        moduleInputPath = string.concat(moduleInputPath, vm.envString("MODULE_INPUT_FILENAME"));
        moduleInputJson = vm.readFile(moduleInputPath);

        // output path to later save the deployed module (not needed in view mode)
        if (!viewMode) {
            moduleOutputPath = string.concat(basePath, "outputs/makina-x-modules/");
            moduleOutputPath = string.concat(moduleOutputPath, vm.envString("MODULE_OUTPUT_FILENAME"));
        }
    }

    function deployment() public view returns (address) {
        return module;
    }

    function run() public {
        ModuleFactory moduleFactory = ModuleFactory(vm.parseJsonAddress(infraOutputJson, ".ModuleFactory"));

        IMakinaXModule.MakinaXModuleInitParams memory params = _parseInitParams();
        bytes32 salt = vm.parseJsonBytes32(moduleInputJson, ".salt");
        bytes32 referralKey = vm.parseJsonBytes32(moduleInputJson, ".referralKey");

        if (viewMode) {
            bytes memory callData = abi.encodeCall(ModuleFactory.createModuleFree, (params, salt, referralKey));
            _logCalldata(address(moduleFactory), callData);
            return;
        }

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        module = moduleFactory.createModuleFree(params, salt, referralKey);

        vm.stopBroadcast();

        _writeOutput();
    }

    function _parseInitParams() internal view returns (IMakinaXModule.MakinaXModuleInitParams memory) {
        return IMakinaXModule.MakinaXModuleInitParams({
            safe: vm.parseJsonAddress(moduleInputJson, ".safe"),
            initialOperatingMode: IMakinaXGovernable.OperatingMode(
                vm.parseJsonUint(moduleInputJson, ".initialOperatingMode")
            ),
            initialAllowedInstrRoot: vm.parseJsonBytes32(moduleInputJson, ".initialAllowedInstrRoot"),
            initialMaxPositionIncreaseLossBps: vm.parseJsonUint(moduleInputJson, ".initialMaxPositionIncreaseLossBps"),
            initialMaxPositionDecreaseLossBps: vm.parseJsonUint(moduleInputJson, ".initialMaxPositionDecreaseLossBps"),
            initialInstrCooldownDuration: vm.parseJsonUint(moduleInputJson, ".initialInstrCooldownDuration"),
            initialMaxSwapLossBps: vm.parseJsonUint(moduleInputJson, ".initialMaxSwapLossBps"),
            initialSwapCooldownDuration: vm.parseJsonUint(moduleInputJson, ".initialSwapCooldownDuration")
        });
    }

    function _logCalldata(address moduleFactory, bytes memory callData) internal pure {
        console2.log("Target (ModuleFactory):", moduleFactory);
        console2.log("Calldata:");
        console2.logBytes(callData);
    }

    function _writeOutput() internal {
        string memory key = "key-create-module-free-output-file";
        vm.writeJson(vm.serializeAddress(key, "MakinaXModule", module), moduleOutputPath);
    }
}

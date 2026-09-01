// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IMakinaXGovernable} from "../../src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

/// @notice Deploys a single MakinaXModule clone through `ModuleFactory.createModuleFree`.
///
/// Env vars:
///   INFRA_OUTPUT_FILENAME  - infra output file holding the ModuleFactory address
///                            (under script/deploy/outputs/infra/)
///   MODULE_INPUT_FILENAME  - module init params input file
///                            (under script/deploy/inputs/modules/)
///   MODULE_OUTPUT_FILENAME - file to write the deployed module address to
///                            (under script/deploy/outputs/modules/, unused when VIEW_MODE is true)
///   VIEW_MODE (optional)   - if true, logs the ModuleFactory call calldata instead of deploying
contract CreateModuleFree is Script {
    using stdJson for string;

    string public moduleInputJson;
    string public moduleOutputPath;

    bool public viewMode;

    ModuleFactory public moduleFactory;

    address public module;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);
    }

    /// @dev Test hook to set the ModuleFactory and the module input/output filenames explicitly, instead of having
    ///      `run` resolve them from the env vars and the infra output file.
    function setParams(address _moduleFactory, string memory moduleInputFilename, string memory moduleOutputFilename)
        public
    {
        moduleFactory = ModuleFactory(_moduleFactory);

        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        // load module init params
        moduleInputJson = vm.readFile(string.concat(basePath, "inputs/modules/", moduleInputFilename));

        // output path to later save the deployed module
        moduleOutputPath = string.concat(basePath, "outputs/modules/", moduleOutputFilename);
    }

    function deployment() public view returns (address) {
        return module;
    }

    function run() public {
        if (address(moduleFactory) == address(0)) {
            _loadParamsFromEnv();
        }

        IMakinaXModule.MakinaXModuleInitParams memory params = _parseInitParams();
        bytes32 salt = vm.parseJsonBytes32(moduleInputJson, ".salt");
        bytes32 referralKey = vm.parseJsonBytes32(moduleInputJson, ".referralKey");

        if (viewMode) {
            bytes memory callData = abi.encodeCall(ModuleFactory.createModuleFree, (params, salt, referralKey));
            _logCalldata(address(moduleFactory), callData);
            return;
        }

        vm.startBroadcast();

        module = moduleFactory.createModuleFree(params, salt, referralKey);

        vm.stopBroadcast();

        _writeOutput();
    }

    /// @dev Calls `setParams` with this script's env vars, reading the factory address from the infra output file.
    ///      The output filename is not needed in view mode.
    function _loadParamsFromEnv() internal {
        string memory infraOutputPath = string.concat(
            vm.projectRoot(), "/script/deployments/outputs/makina-x-infra/", vm.envString("INFRA_OUTPUT_FILENAME")
        );
        string memory moduleOutputFilename = viewMode ? "" : vm.envString("MODULE_OUTPUT_FILENAME");

        setParams(
            vm.parseJsonAddress(vm.readFile(infraOutputPath), ".ModuleFactory"),
            vm.envString("MODULE_INPUT_FILENAME"),
            moduleOutputFilename
        );
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

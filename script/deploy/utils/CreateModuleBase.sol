// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// console logging is used to expose the call's calldata in view mode
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IMakinaXGovernable} from "../../../src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "../../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../../src/factory/ModuleFactory.sol";

/// @notice Shared logic of the scripts creating a MakinaXModule clone through the `ModuleFactory`.
/// @dev Concrete scripts implement `_createModuleCalldata`, encoding the factory call to perform.
///
/// Modes, selected by the `VIEW_MODE` env var:
///   - Broadcast (default): sends the call and writes the deployed module address to the output file.
///   - View (`VIEW_MODE=true`): logs the factory address and the calldata, sends nothing and writes no file.
///
/// Env vars:
///   INFRA_OUTPUT_FILENAME  - infra output file holding the ModuleFactory address
///                            (under script/deploy/outputs/infra/)
///   MODULE_INPUT_FILENAME  - module init params input file
///                            (under script/deploy/inputs/modules/)
///   MODULE_OUTPUT_FILENAME - file to write the deployed module address to
///                            (under script/deploy/outputs/modules/, broadcast mode only)
///   VIEW_MODE (optional)   - true for view mode, unset or false for broadcast mode
abstract contract CreateModuleBase is Script {
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

        bytes memory callData = _createModuleCalldata(
            _parseInitParams(),
            vm.parseJsonBytes32(moduleInputJson, ".salt"),
            vm.parseJsonBytes32(moduleInputJson, ".referralKey")
        );

        if (viewMode) {
            _logCalldata(callData);
            return;
        }

        vm.startBroadcast();

        module = abi.decode(Address.functionCall(address(moduleFactory), callData), (address));

        vm.stopBroadcast();

        _writeOutput();
    }

    /// @dev Encodes the `ModuleFactory` call deploying the module for the given init params.
    function _createModuleCalldata(
        IMakinaXModule.MakinaXModuleInitParams memory params,
        bytes32 salt,
        bytes32 referralKey
    ) internal view virtual returns (bytes memory);

    /// @dev Calls `setParams` with this script's env vars, reading the factory address from the infra output file.
    ///      The output filename is not needed in view mode.
    function _loadParamsFromEnv() internal {
        string memory infraOutputPath =
            string.concat(vm.projectRoot(), "/script/deploy/outputs/infra/", vm.envString("INFRA_OUTPUT_FILENAME"));
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

    function _logCalldata(bytes memory callData) internal view {
        console2.log("Target (ModuleFactory):", address(moduleFactory));
        console2.log("Calldata:");
        console2.logBytes(callData);
    }

    function _writeOutput() internal {
        string memory key = "key-create-module-output-file";
        vm.writeJson(vm.serializeAddress(key, "MakinaXModule", module), moduleOutputPath);
    }
}

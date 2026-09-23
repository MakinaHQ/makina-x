// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IMakinaXGovernable} from "../../src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "../../src/interfaces/IMakinaXModule.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {AMGovCalldata} from "./utils/AMGovCalldata.sol";

/// @notice Shared logic of the scripts creating a MakinaXModule clone through the `ModuleFactory`.
/// @dev Concrete scripts implement `_createCall`, building the factory call to perform.
///
/// Modes, selected by the `VIEW_MODE` env var:
///   - Broadcast (default): sends the call and writes the deployed module address to the output file.
///   - View (`VIEW_MODE=true`): logs the factory address and the calldata, alongside its `AccessManager.schedule`
///     wrapper. Sends nothing and writes no file.
///
/// Env vars:
///   INFRA_OUTPUT_FILENAME  - infra output file holding the ModuleFactory address
///                            (under script/deploy/outputs/infra/)
///   MODULE_INPUT_FILENAME  - module init params input file
///                            (under script/deploy/inputs/modules/)
///   MODULE_OUTPUT_FILENAME - file to write the deployed module address to
///                            (under script/deploy/outputs/modules/, broadcast mode only)
///   VIEW_MODE (optional)   - true for view mode, unset or false for broadcast mode
abstract contract CreateModuleBase is Script, AMGovCalldata {
    string public moduleInputJson;
    string public moduleOutputPath;

    bool public viewMode;

    ModuleFactory public moduleFactory;

    address public module;

    /// @dev Test hook to set the ModuleFactory and the module input/output filenames explicitly, instead of having
    ///      `run` resolve them from the env vars and the infra output file. An empty output filename skips writing
    ///      the output file.
    function setParams(address _moduleFactory, string memory moduleInputFilename, string memory moduleOutputFilename)
        public
    {
        moduleFactory = ModuleFactory(_moduleFactory);

        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        moduleInputJson = vm.readFile(string.concat(basePath, "inputs/modules/", moduleInputFilename));

        moduleOutputPath = bytes(moduleOutputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/modules/", moduleOutputFilename);
    }

    /// @dev Test hook to select the mode explicitly, instead of having `run` read it from the `VIEW_MODE` env var.
    function setViewMode(bool _viewMode) public {
        viewMode = _viewMode;
    }

    function deployment() public view returns (address) {
        return module;
    }

    function run() public {
        if (address(moduleFactory) == address(0)) {
            loadParamsFromEnv();
        }

        Call memory call = _createCall();

        if (viewMode) {
            _logCall(call);
            return;
        }

        vm.startBroadcast();

        module = abi.decode(Address.functionCall(call.target, call.data), (address));

        vm.stopBroadcast();

        if (bytes(moduleOutputPath).length != 0) {
            _writeOutput();
        }
    }

    /// @dev The `ModuleFactory` call deploying the module, built from the input file.
    function _createCall() internal view virtual returns (Call memory);

    /// @dev Calls `setParams` with this script's env vars, reading the factory address from the infra output file.
    ///      The output filename is not needed in view mode.
    function loadParamsFromEnv() public {
        viewMode = vm.envOr("VIEW_MODE", false);

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

    function _writeOutput() internal {
        string memory key = "key-create-module-output-file";
        vm.writeJson(vm.serializeAddress(key, "MakinaXModule", module), moduleOutputPath);
    }
}

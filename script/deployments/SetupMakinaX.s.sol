// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// console logging is used intentionally to expose the calls' calldata in view mode
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Shared logic for the MakinaX infra setup scripts. Each builds one list of privileged calls,
///         either broadcasting them or logging their target and calldata.
/// @dev Alongside each call's raw calldata, view mode logs the `AccessManager.schedule` wrapper.
///
/// Env vars:
///   INFRA_INPUT_FILENAME   - infra input file holding the AccessManager address
///                            (under script/deployments/inputs/makina-x-infra/)
///   INFRA_OUTPUT_FILENAME  - infra output file holding the deployed contract addresses
///                            (under script/deployments/outputs/makina-x-infra/)
///   VIEW_MODE (optional)   - if true, logs each call's target + calldata instead of broadcasting
///   TEST_SENDER (optional) - account to broadcast from
abstract contract SetupMakinaX is Base, Script {
    string public deploymentInputJson;
    string public deploymentOutputJson;

    bool public viewMode;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);

        string memory deploymentInputFilename = vm.envString("INFRA_INPUT_FILENAME");
        string memory deploymentOutputFilename = vm.envString("INFRA_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load deployment input params
        string memory deploymentInputPath = string.concat(basePath, "inputs/makina-x-infra/");
        deploymentInputPath = string.concat(deploymentInputPath, deploymentInputFilename);
        deploymentInputJson = vm.readFile(deploymentInputPath);

        // load deployment output params
        string memory deploymentOutputPath = string.concat(basePath, "outputs/makina-x-infra/");
        deploymentOutputPath = string.concat(deploymentOutputPath, deploymentOutputFilename);
        deploymentOutputJson = vm.readFile(deploymentOutputPath);
    }

    function run() public {
        Call[] memory calls = _calls();

        if (viewMode) {
            _logCalls(calls);
            return;
        }

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        _executeCalls(calls);

        vm.stopBroadcast();
    }

    /// @dev The calls to submit, in execution order.
    function _calls() internal view virtual returns (Call[] memory calls);

    /// @dev Label describing the target of this script's calls, used in view mode.
    function _targetLabel() internal pure virtual returns (string memory);

    function _accessManager() internal view returns (address) {
        return vm.parseJsonAddress(deploymentInputJson, ".accessManager");
    }

    function _readInfra() internal view returns (MakinaXInfra memory) {
        return MakinaXInfra({
            registry: MakinaXRegistry(vm.parseJsonAddress(deploymentOutputJson, ".MakinaXRegistry")),
            moduleFactory: ModuleFactory(vm.parseJsonAddress(deploymentOutputJson, ".ModuleFactory")),
            makinaXModuleImplem: vm.parseJsonAddress(deploymentOutputJson, ".MakinaXModuleImplem"),
            flashLoanModule: FlashLoanModule(vm.parseJsonAddress(deploymentOutputJson, ".FlashLoanModule"))
        });
    }

    /// @dev Reads the bridge encoders that were deployed, keyed by bridge id, from the infra output file.
    function _readBridgeEncoders() internal view returns (uint16[] memory bridgeIds, address[] memory encoders) {
        require(vm.keyExistsJson(deploymentOutputJson, ".BridgeEncoders"), "missing BridgeEncoders in output");

        string[] memory keys = vm.parseJsonKeys(deploymentOutputJson, ".BridgeEncoders");

        bridgeIds = new uint16[](keys.length);
        encoders = new address[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            bridgeIds[i] = uint16(vm.parseUint(keys[i]));
            encoders[i] = vm.parseJsonAddress(deploymentOutputJson, string.concat(".BridgeEncoders.", keys[i]));
        }
    }

    /// @dev Concatenates two call batches, preserving order.
    function _concatCalls(Call[] memory first, Call[] memory second) internal pure returns (Call[] memory calls) {
        calls = new Call[](first.length + second.length);
        for (uint256 i; i < first.length; ++i) {
            calls[i] = first[i];
        }
        for (uint256 i; i < second.length; ++i) {
            calls[first.length + i] = second[i];
        }
    }

    /// @dev A `schedule` `when` of zero lets the AccessManager queue the operation at the earliest allowed
    ///      time, i.e. once the caller's execution delay has elapsed.
    function _logCalls(Call[] memory calls) internal view {
        console2.log("AccessManager:", _accessManager());

        for (uint256 i; i < calls.length; ++i) {
            console2.log(_targetLabel(), calls[i].target);
            console2.log("Calldata:");
            console2.logBytes(calls[i].data);

            console2.log("AccessManager schedule calldata:");
            console2.logBytes(abi.encodeCall(IAccessManager.schedule, (calls[i].target, calls[i].data, 0)));

            console2.log("\n");
        }
    }
}

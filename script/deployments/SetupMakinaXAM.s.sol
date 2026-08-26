// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Configures the AccessManager function roles for the MakinaX infrastructure.
/// @dev The broadcasting account must have the `ADMIN_ROLE` in the AccessManager provided in the infra input file.
///
/// Env vars:
///   INFRA_INPUT_FILENAME   - infra input file holding the AccessManager address
///                            (under script/deployments/inputs/makina-x-infra/)
///   INFRA_OUTPUT_FILENAME  - infra output file holding the deployed contract addresses
///                            (under script/deployments/outputs/makina-x-infra/)
///   VIEW_MODE (optional)   - if true, logs the AccessManager calls calldata instead of broadcasting
///   TEST_SENDER (optional) - account to broadcast from
contract SetupMakinaXAM is Base, Script {
    using stdJson for string;

    string public deploymentInputJson;
    string public deploymentOutputJson;

    bool public viewMode;

    address private _accessManager;

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
        _accessManager = vm.parseJsonAddress(deploymentInputJson, ".accessManager");

        Call[] memory calls = _amFunctionRoleCalls(_accessManager, _readInfra());

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

    function _readInfra() internal view returns (MakinaXInfra memory) {
        return MakinaXInfra({
            registry: MakinaXRegistry(vm.parseJsonAddress(deploymentOutputJson, ".MakinaXRegistry")),
            moduleFactory: ModuleFactory(vm.parseJsonAddress(deploymentOutputJson, ".ModuleFactory")),
            makinaXModuleImplem: vm.parseJsonAddress(deploymentOutputJson, ".MakinaXModuleImplem"),
            flashLoanModule: FlashLoanModule(vm.parseJsonAddress(deploymentOutputJson, ".FlashLoanModule"))
        });
    }

    function _logCalls(Call[] memory calls) internal pure {
        for (uint256 i; i < calls.length; ++i) {
            console2.log("Target (AccessManager):", calls[i].target);
            console2.log("Calldata:");
            console2.logBytes(calls[i].data);
        }
    }
}

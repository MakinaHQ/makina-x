// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {Base} from "../../test/base/Base.sol";

contract SetupMakinaXAM is Base, Script {
    using stdJson for string;

    string public deploymentInputJson;
    string public deploymentOutputJson;

    address private _accessManager;

    constructor() {
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

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        setupAMFunctionRoles(
            _accessManager,
            MakinaXInfra({
                registry: MakinaXRegistry(vm.parseJsonAddress(deploymentOutputJson, ".MakinaXRegistry")),
                moduleFactory: ModuleFactory(vm.parseJsonAddress(deploymentOutputJson, ".ModuleFactory")),
                makinaXModuleImplem: vm.parseJsonAddress(deploymentOutputJson, ".MakinaXModuleImplem"),
                flashLoanModule: FlashLoanModule(vm.parseJsonAddress(deploymentOutputJson, ".FlashLoanModule"))
            })
        );

        vm.stopBroadcast();
    }
}

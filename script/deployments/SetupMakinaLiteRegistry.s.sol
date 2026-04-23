// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {MakinaLiteRegistry} from "../../src/registry/MakinaLiteRegistry.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {Base} from "../../test/base/Base.sol";

contract SetupMakinaLiteRegistry is Base, Script {
    using stdJson for string;

    string public deploymentInputJson;
    string public deploymentOutputJson;

    constructor() {
        string memory deploymentInputFilename = vm.envString("INFRA_INPUT_FILENAME");
        string memory deploymentOutputFilename = vm.envString("INFRA_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load deployment input params
        string memory deploymentInputPath = string.concat(basePath, "inputs/makina-lite-infra/");
        deploymentInputPath = string.concat(deploymentInputPath, deploymentInputFilename);
        deploymentInputJson = vm.readFile(deploymentInputPath);

        // load deployment output params
        string memory deploymentOutputPath = string.concat(basePath, "outputs/makina-lite-infra/");
        deploymentOutputPath = string.concat(deploymentOutputPath, deploymentOutputFilename);
        deploymentOutputJson = vm.readFile(deploymentOutputPath);
    }

    function run() public {
        address feeCollector = vm.parseJsonAddress(deploymentInputJson, ".feeCollector");

        MakinaLiteInfra memory infra = MakinaLiteInfra({
            registry: MakinaLiteRegistry(vm.parseJsonAddress(deploymentOutputJson, ".MakinaLiteRegistry")),
            moduleFactory: ModuleFactory(vm.parseJsonAddress(deploymentOutputJson, ".ModuleFactory")),
            makinaLiteModuleImplem: vm.parseJsonAddress(deploymentOutputJson, ".MakinaLiteModuleImplem"),
            flashLoanModule: FlashLoanModule(vm.parseJsonAddress(deploymentOutputJson, ".FlashLoanModule"))
        });

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        setupMakinaLiteRegistry(infra, feeCollector);

        _registerBridgeEncoders(infra.registry);

        vm.stopBroadcast();
    }

    function _registerBridgeEncoders(MakinaLiteRegistry registry) internal {
        uint256 len = _bridgesTargetsLength();
        for (uint256 i; i < len; ++i) {
            uint16 bridgeId = uint16(
                vm.parseJsonUint(deploymentInputJson, string.concat(".bridgesTargets[", vm.toString(i), "].bridgeId"))
            );
            address encoder = vm.parseJsonAddress(
                deploymentOutputJson, string.concat(".BridgeEncoders.", vm.toString(uint256(bridgeId)))
            );
            registry.setBridgeEncoder(bridgeId, encoder);
        }
    }

    function _bridgesTargetsLength() internal view returns (uint256 len) {
        while (vm.keyExistsJson(deploymentInputJson, string.concat(".bridgesTargets[", vm.toString(len), "]"))) {
            ++len;
        }
    }
}

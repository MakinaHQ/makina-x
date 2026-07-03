// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {stdJson} from "forge-std/StdJson.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {AcrossV4BridgeEncoder} from "src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {LayerZeroV2BridgeEncoder} from "src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {MakinaXRegistry} from "src/registry/MakinaXRegistry.sol";

import {DeployMakinaX} from "script/deployments/DeployMakinaX.s.sol";
import {SetupMakinaXAM} from "script/deployments/SetupMakinaXAM.s.sol";
import {SetupMakinaXRegistry} from "script/deployments/SetupMakinaXRegistry.s.sol";

import {Roles} from "../utils/Roles.sol";
import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Scripts_Test is Base_Test {
    using stdJson for string;

    DeployMakinaX public deployMakinaX;
    SetupMakinaXRegistry public setupMakinaXRegistry;
    SetupMakinaXAM public setupMakinaXAM;

    function setUp() public override {
        vm.setEnv("INFRA_INPUT_FILENAME", "Mainnet-Test.json");
        vm.setEnv("INFRA_OUTPUT_FILENAME", "Mainnet-Test.json");

        // In provided access manager test instance, admin has permissions for setup below
        address admin = 0xae7f67EE9B8c465ACE4a1ec1138FaA483d93691A;
        vm.setEnv("TEST_SENDER", vm.toString(admin));
    }

    function test_LoadedState() public {
        deployMakinaX = new DeployMakinaX();

        address accessManager = vm.parseJsonAddress(deployMakinaX.inputJson(), ".accessManager");
        assertTrue(accessManager != address(0));

        address weirollVM = vm.parseJsonAddress(deployMakinaX.inputJson(), ".weirollVM");
        assertTrue(weirollVM != address(0));

        address feeCollector = vm.parseJsonAddress(deployMakinaX.inputJson(), ".feeCollector");
        assertTrue(feeCollector != address(0));

        address morpho = vm.parseJsonAddress(deployMakinaX.inputJson(), ".flashLoanProviders.morpho");
        assertTrue(morpho != address(0));

        assertTrue(vm.keyExistsJson(deployMakinaX.inputJson(), ".bridgesTargets[0]"));
    }

    function testScript_DeployMakinaX() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaX = new DeployMakinaX();
        deployMakinaX.run();

        setupMakinaXRegistry = new SetupMakinaXRegistry();
        setupMakinaXRegistry.run();

        (MakinaXInfra memory infra, uint16[] memory bridgeIds, address[] memory bridgeEncoders) =
            deployMakinaX.deployment();

        string memory inputJson = deployMakinaX.inputJson();

        address expectedAccessManager = vm.parseJsonAddress(inputJson, ".accessManager");
        address expectedWeirollVM = vm.parseJsonAddress(inputJson, ".weirollVM");
        address expectedFeeCollector = vm.parseJsonAddress(inputJson, ".feeCollector");
        address expectedMorpho = vm.parseJsonAddress(inputJson, ".flashLoanProviders.morpho");

        // Check that MakinaXRegistry is correctly set up
        assertEq(infra.registry.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.registry.moduleImplementation(), infra.makinaXModuleImplem);
        assertEq(infra.registry.feeCollector(), expectedFeeCollector);
        assertEq(infra.registry.flashLoanModule(), address(infra.flashLoanModule));

        // Check that MakinaXRegistry and ModuleFactory are authed by the provided access manager
        assertEq(infra.registry.authority(), expectedAccessManager);
        assertEq(infra.moduleFactory.authority(), expectedAccessManager);

        // Check that FlashLoanModule is correctly wired up
        assertEq(infra.flashLoanModule.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.flashLoanModule.morpho(), expectedMorpho);

        // Check that MakinaXModule implementation is correctly wired up
        assertEq(IMakinaXModule(infra.makinaXModuleImplem).registry(), address(infra.registry));
        assertEq(IMakinaXModule(infra.makinaXModuleImplem).weirollVm(), address(expectedWeirollVM));

        // Check that bridge encoders are correctly set up and registered
        assertEq(bridgeIds.length, bridgeEncoders.length);
        uint256 expectedBridgesLen = _bridgesTargetsLength(inputJson);
        assertEq(bridgeIds.length, expectedBridgesLen);

        for (uint256 i; i < expectedBridgesLen; ++i) {
            string memory base = string.concat(".bridgesTargets[", vm.toString(i), "]");
            uint16 expectedBridgeId = uint16(vm.parseJsonUint(inputJson, string.concat(base, ".bridgeId")));

            assertEq(bridgeIds[i], expectedBridgeId);
            assertEq(infra.registry.getBridgeEncoder(expectedBridgeId), bridgeEncoders[i]);

            if (expectedBridgeId == ACROSS_V4_BRIDGE_ID) {
                address expectedSpokePool = vm.parseJsonAddress(inputJson, string.concat(base, ".acrossV4SpokePool"));
                assertEq(AcrossV4BridgeEncoder(bridgeEncoders[i]).acrossV4SpokePool(), expectedSpokePool);
                assertEq(AcrossV4BridgeEncoder(bridgeEncoders[i]).authority(), expectedAccessManager);
            } else if (expectedBridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
                assertEq(LayerZeroV2BridgeEncoder(bridgeEncoders[i]).authority(), expectedAccessManager);
            } else if (expectedBridgeId == CCTP_V2_BRIDGE_ID) {
                address expectedMessenger = vm.parseJsonAddress(inputJson, string.concat(base, ".cctpV2TokenMessenger"));
                assertEq(CctpV2BridgeEncoder(bridgeEncoders[i]).cctpV2TokenMessenger(), expectedMessenger);
                assertEq(CctpV2BridgeEncoder(bridgeEncoders[i]).authority(), expectedAccessManager);
            } else {
                revert("unsupported bridgeId in test fixture");
            }
        }
    }

    function testScript_SetupMakinaXAM() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaX = new DeployMakinaX();
        deployMakinaX.run();

        setupMakinaXAM = new SetupMakinaXAM();
        setupMakinaXAM.run();

        (MakinaXInfra memory infra,,) = deployMakinaX.deployment();

        address accessManager = vm.parseJsonAddress(deployMakinaX.inputJson(), ".accessManager");

        // Transparent proxy admins' upgradeAndCall is guarded by INFRA_UPGRADE_ROLE
        assertEq(
            IAccessManager(accessManager)
                .getTargetFunctionRole(getProxyAdmin(address(infra.registry)), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
        assertEq(
            IAccessManager(accessManager)
                .getTargetFunctionRole(getProxyAdmin(address(infra.moduleFactory)), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );

        // MakinaXRegistry setters are guarded by INFRA_CONFIG_ROLE
        bytes4[5] memory registrySetterSelectors = [
            MakinaXRegistry.setModuleFactory.selector,
            MakinaXRegistry.setModuleImplementation.selector,
            MakinaXRegistry.setFeeCollector.selector,
            MakinaXRegistry.setFlashLoanModule.selector,
            MakinaXRegistry.setBridgeEncoder.selector
        ];
        for (uint256 i; i < registrySetterSelectors.length; ++i) {
            assertEq(
                IAccessManager(accessManager)
                    .getTargetFunctionRole(address(infra.registry), registrySetterSelectors[i]),
                Roles.INFRA_CONFIG_ROLE
            );
        }
    }

    function _bridgesTargetsLength(string memory inputJson) internal view returns (uint256 len) {
        while (vm.keyExistsJson(inputJson, string.concat(".bridgesTargets[", vm.toString(len), "]"))) {
            ++len;
        }
    }
}

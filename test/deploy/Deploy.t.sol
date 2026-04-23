// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {stdJson} from "forge-std/StdJson.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {IMakinaLiteModule} from "src/interfaces/IMakinaLiteModule.sol";
import {AcrossV4BridgeEncoder} from "src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {LayerZeroV2BridgeEncoder} from "src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {MakinaLiteRegistry} from "src/registry/MakinaLiteRegistry.sol";

import {DeployMakinaLite} from "script/deployments/DeployMakinaLite.s.sol";
import {SetupMakinaLiteAM} from "script/deployments/SetupMakinaLiteAM.s.sol";
import {SetupMakinaLiteRegistry} from "script/deployments/SetupMakinaLiteRegistry.s.sol";

import {Roles} from "../utils/Roles.sol";
import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Scripts_Test is Base_Test {
    using stdJson for string;

    DeployMakinaLite public deployMakinaLite;
    SetupMakinaLiteRegistry public setupMakinaLiteRegistry;
    SetupMakinaLiteAM public setupMakinaLiteAM;

    function setUp() public override {
        vm.setEnv("INFRA_INPUT_FILENAME", "Mainnet-Test.json");
        vm.setEnv("INFRA_OUTPUT_FILENAME", "Mainnet-Test.json");

        // In provided access manager test instance, admin has permissions for setup below
        address admin = 0xae7f67EE9B8c465ACE4a1ec1138FaA483d93691A;
        vm.setEnv("TEST_SENDER", vm.toString(admin));
    }

    function test_LoadedState() public {
        deployMakinaLite = new DeployMakinaLite();

        address accessManager = vm.parseJsonAddress(deployMakinaLite.inputJson(), ".accessManager");
        assertTrue(accessManager != address(0));

        address weirollVM = vm.parseJsonAddress(deployMakinaLite.inputJson(), ".weirollVM");
        assertTrue(weirollVM != address(0));

        address feeCollector = vm.parseJsonAddress(deployMakinaLite.inputJson(), ".feeCollector");
        assertTrue(feeCollector != address(0));

        address morpho = vm.parseJsonAddress(deployMakinaLite.inputJson(), ".flashLoanProviders.morpho");
        assertTrue(morpho != address(0));

        assertTrue(vm.keyExistsJson(deployMakinaLite.inputJson(), ".bridgesTargets[0]"));
    }

    function testScript_DeployMakinaLite() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaLite = new DeployMakinaLite();
        deployMakinaLite.run();

        setupMakinaLiteRegistry = new SetupMakinaLiteRegistry();
        setupMakinaLiteRegistry.run();

        (MakinaLiteInfra memory infra, uint16[] memory bridgeIds, address[] memory bridgeEncoders) =
            deployMakinaLite.deployment();

        string memory inputJson = deployMakinaLite.inputJson();

        address expectedAccessManager = vm.parseJsonAddress(inputJson, ".accessManager");
        address expectedWeirollVM = vm.parseJsonAddress(inputJson, ".weirollVM");
        address expectedFeeCollector = vm.parseJsonAddress(inputJson, ".feeCollector");
        address expectedMorpho = vm.parseJsonAddress(inputJson, ".flashLoanProviders.morpho");

        // Check that MakinaLiteRegistry is correctly set up
        assertEq(infra.registry.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.registry.moduleImplementation(), infra.makinaLiteModuleImplem);
        assertEq(infra.registry.feeCollector(), expectedFeeCollector);
        assertEq(infra.registry.flashLoanModule(), address(infra.flashLoanModule));

        // Check that MakinaLiteRegistry and ModuleFactory are authed by the provided access manager
        assertEq(infra.registry.authority(), expectedAccessManager);
        assertEq(infra.moduleFactory.authority(), expectedAccessManager);

        // Check that FlashLoanModule is correctly wired up
        assertEq(infra.flashLoanModule.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.flashLoanModule.morpho(), expectedMorpho);

        // Check that MakinaLiteModule implementation is correctly wired up
        assertEq(IMakinaLiteModule(infra.makinaLiteModuleImplem).registry(), address(infra.registry));
        assertEq(IMakinaLiteModule(infra.makinaLiteModuleImplem).weirollVm(), address(expectedWeirollVM));

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

    function testScript_SetupMakinaLiteAM() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaLite = new DeployMakinaLite();
        deployMakinaLite.run();

        setupMakinaLiteAM = new SetupMakinaLiteAM();
        setupMakinaLiteAM.run();

        (MakinaLiteInfra memory infra,,) = deployMakinaLite.deployment();

        address accessManager = vm.parseJsonAddress(deployMakinaLite.inputJson(), ".accessManager");

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

        // MakinaLiteRegistry setters are guarded by INFRA_CONFIG_ROLE
        bytes4[5] memory registrySetterSelectors = [
            MakinaLiteRegistry.setModuleFactory.selector,
            MakinaLiteRegistry.setModuleImplementation.selector,
            MakinaLiteRegistry.setFeeCollector.selector,
            MakinaLiteRegistry.setFlashLoanModule.selector,
            MakinaLiteRegistry.setBridgeEncoder.selector
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

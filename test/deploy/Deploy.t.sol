// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {AcrossV4BridgeEncoder} from "src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {LayerZeroV2BridgeEncoder} from "src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {MakinaXRegistry} from "src/registry/MakinaXRegistry.sol";
import {ModuleFactory} from "src/factory/ModuleFactory.sol";

import {CreateModule} from "script/deployments/CreateModule.s.sol";
import {CreateModuleFree} from "script/deployments/CreateModuleFree.s.sol";
import {DeployMakinaX} from "script/deployments/DeployMakinaX.s.sol";

import {Roles} from "../utils/Roles.sol";
import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Scripts_Test is Base_Test {
    DeployMakinaX public deployMakinaX;
    CreateModule public createModule;
    CreateModuleFree public createModuleFree;

    function setUp() public override {
        vm.setEnv("INFRA_INPUT_FILENAME", "Mainnet-Test.json");
        vm.setEnv("INFRA_OUTPUT_FILENAME", "Mainnet-Test.json");
        vm.setEnv("SKIP_AM_SETUP", "false");
        vm.setEnv("VIEW_MODE", "false");
    }

    function test_LoadedState() public {
        deployMakinaX = new DeployMakinaX();

        address superAdmin = vm.parseJsonAddress(deployMakinaX.inputJson(), ".superAdminRoleGrant.account");
        assertTrue(superAdmin != address(0));

        address feeCollector = vm.parseJsonAddress(deployMakinaX.inputJson(), ".feeCollector");
        assertTrue(feeCollector != address(0));

        address morpho = vm.parseJsonAddress(deployMakinaX.inputJson(), ".flashLoanProviders.morpho");
        assertTrue(morpho != address(0));

        assertTrue(vm.keyExistsJson(deployMakinaX.inputJson(), ".otherRoleGrants[0]"));
        assertTrue(vm.keyExistsJson(deployMakinaX.inputJson(), ".bridgesTargets[0]"));

        // no factory needed here, only the input files are inspected
        createModule = new CreateModule();
        createModule.setParams(address(0), "Mainnet-Test.json", "Mainnet-Test.json");

        address moduleSafe = vm.parseJsonAddress(createModule.moduleInputJson(), ".safe");
        assertTrue(moduleSafe != address(0));

        bytes32 moduleSalt = vm.parseJsonBytes32(createModule.moduleInputJson(), ".salt");
        assertTrue(moduleSalt != bytes32(0));

        assertTrue(vm.keyExistsJson(createModule.moduleInputJson(), ".initialProvider"));

        createModuleFree = new CreateModuleFree();
        createModuleFree.setParams(address(0), "Mainnet-Test-Free.json", "Mainnet-Test-Free.json");

        address freeModuleSafe = vm.parseJsonAddress(createModuleFree.moduleInputJson(), ".safe");
        assertTrue(freeModuleSafe != address(0));

        bytes32 freeModuleSalt = vm.parseJsonBytes32(createModuleFree.moduleInputJson(), ".salt");
        assertTrue(freeModuleSalt != bytes32(0));
    }

    function testScript_DeployMakinaX() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaX = new DeployMakinaX();
        deployMakinaX.run();

        (MakinaXInfra memory infra, uint16[] memory bridgeIds, address[] memory bridgeEncoders) =
            deployMakinaX.deployment();

        string memory inputJson = deployMakinaX.inputJson();

        address accessManager = address(infra.accessManager);
        address expectedFeeCollector = vm.parseJsonAddress(inputJson, ".feeCollector");
        address expectedMorpho = vm.parseJsonAddress(inputJson, ".flashLoanProviders.morpho");

        // Check that a new AccessManager is deployed
        assertTrue(accessManager != address(0));

        // Check that a new WeirollVM is deployed
        assertTrue(IMakinaXModule(infra.makinaXModuleImplem).weirollVm().code.length > 0);

        // Check that MakinaXRegistry is correctly set up
        assertEq(infra.registry.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.registry.moduleImplementation(), infra.makinaXModuleImplem);
        assertEq(infra.registry.feeCollector(), expectedFeeCollector);
        assertEq(infra.registry.flashLoanModule(), address(infra.flashLoanModule));

        // Check that MakinaXRegistry and ModuleFactory are authed by the deployed access manager
        assertEq(infra.registry.authority(), accessManager);
        assertEq(infra.moduleFactory.authority(), accessManager);

        // Check that ModuleFactory is correctly set up
        assertEq(infra.moduleFactory.defaultProvider(), vm.parseJsonAddress(inputJson, ".defaultProvider"));
        assertEq(infra.moduleFactory.defaultSwapFeeRate(), vm.parseJsonUint(inputJson, ".defaultSwapFeeRate"));
        assertEq(infra.moduleFactory.freeDeployment(), vm.parseJsonBool(inputJson, ".freeDeployment"));

        // Check that FlashLoanModule is correctly wired up
        assertEq(infra.flashLoanModule.moduleFactory(), address(infra.moduleFactory));
        assertEq(infra.flashLoanModule.morpho(), expectedMorpho);

        // Check that MakinaXModule implementation is correctly wired up
        assertEq(IMakinaXModule(infra.makinaXModuleImplem).registry(), address(infra.registry));

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
                assertEq(AcrossV4BridgeEncoder(bridgeEncoders[i]).authority(), accessManager);
            } else if (expectedBridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
                assertEq(LayerZeroV2BridgeEncoder(bridgeEncoders[i]).authority(), accessManager);
            } else if (expectedBridgeId == CCTP_V2_BRIDGE_ID) {
                address expectedMessenger = vm.parseJsonAddress(inputJson, string.concat(base, ".cctpV2TokenMessenger"));
                assertEq(CctpV2BridgeEncoder(bridgeEncoders[i]).cctpV2TokenMessenger(), expectedMessenger);
                assertEq(CctpV2BridgeEncoder(bridgeEncoders[i]).authority(), accessManager);
            } else {
                revert("unsupported bridgeId in test fixture");
            }
        }

        _assertAMFunctionRoles(accessManager, infra, bridgeIds, bridgeEncoders);
        _assertAMRoleGrants(accessManager, inputJson);

        // The AccessManager's own proxy admin is owned by the AccessManager itself
        assertEq(Ownable(getProxyAdmin(accessManager)).owner(), accessManager);
    }

    function testScript_CreateModule() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaX = new DeployMakinaX();
        deployMakinaX.setTestMode();
        deployMakinaX.run();

        (MakinaXInfra memory infra,,) = deployMakinaX.deployment();

        createModule = new CreateModule();
        createModule.setParams(address(infra.moduleFactory), "Mainnet-Test.json", "Mainnet-Test.json");
        createModule.run();

        string memory inputJson = createModule.moduleInputJson();
        IMakinaXModule module = IMakinaXModule(createModule.deployment());

        // The deployed module address is written to the output file
        assertEq(vm.parseJsonAddress(vm.readFile(createModule.moduleOutputPath()), ".MakinaXModule"), address(module));

        // The module is a clone of the registered implementation, at the address derived from the input salt
        bytes32 salt = vm.parseJsonBytes32(inputJson, ".salt");
        assertEq(
            address(module),
            Clones.predictDeterministicAddress(infra.makinaXModuleImplem, salt, address(infra.moduleFactory))
        );

        _assertModuleSetup(module, infra, inputJson);

        // Service params are taken from the input file
        assertEq(module.provider(), vm.parseJsonAddress(inputJson, ".initialProvider"));
        assertEq(module.swapFeeRate(), vm.parseJsonUint(inputJson, ".initialSwapFeeRate"));
    }

    function testScript_CreateModuleFree() public {
        vm.createSelectFork({urlOrAlias: "mainnet"});

        deployMakinaX = new DeployMakinaX();
        deployMakinaX.setTestMode();
        deployMakinaX.run();

        (MakinaXInfra memory infra,,) = deployMakinaX.deployment();

        createModuleFree = new CreateModuleFree();
        createModuleFree.setParams(address(infra.moduleFactory), "Mainnet-Test-Free.json", "Mainnet-Test-Free.json");
        createModuleFree.run();

        string memory inputJson = createModuleFree.moduleInputJson();
        IMakinaXModule module = IMakinaXModule(createModuleFree.deployment());

        // The deployed module address is written to the output file
        assertEq(
            vm.parseJsonAddress(vm.readFile(createModuleFree.moduleOutputPath()), ".MakinaXModule"), address(module)
        );

        // The salt is namespaced by the broadcasting account, which is the same default sender as the infra deployer
        bytes32 salt = vm.parseJsonBytes32(inputJson, ".salt");
        bytes32 namespacedSalt = keccak256(abi.encode(deployMakinaX.deployer(), salt));
        assertEq(
            address(module),
            Clones.predictDeterministicAddress(infra.makinaXModuleImplem, namespacedSalt, address(infra.moduleFactory))
        );

        _assertModuleSetup(module, infra, inputJson);

        // Service params are enforced by the factory
        assertEq(module.provider(), infra.moduleFactory.defaultProvider());
        assertEq(module.swapFeeRate(), infra.moduleFactory.defaultSwapFeeRate());
    }

    function _assertModuleSetup(IMakinaXModule module, MakinaXInfra memory infra, string memory inputJson)
        internal
        view
    {
        assertTrue(infra.moduleFactory.isMakinaXModule(address(module)));

        assertEq(module.registry(), address(infra.registry));

        assertEq(module.safe(), vm.parseJsonAddress(inputJson, ".safe"));
        assertEq(uint256(module.operatingMode()), vm.parseJsonUint(inputJson, ".initialOperatingMode"));
        assertEq(module.allowedInstrRoot(), vm.parseJsonBytes32(inputJson, ".initialAllowedInstrRoot"));
        assertEq(module.maxPositionIncreaseLossBps(), vm.parseJsonUint(inputJson, ".initialMaxPositionIncreaseLossBps"));
        assertEq(module.maxPositionDecreaseLossBps(), vm.parseJsonUint(inputJson, ".initialMaxPositionDecreaseLossBps"));
        assertEq(module.instrCooldownDuration(), vm.parseJsonUint(inputJson, ".initialInstrCooldownDuration"));
        assertEq(module.maxSwapLossBps(), vm.parseJsonUint(inputJson, ".initialMaxSwapLossBps"));
        assertEq(module.swapCooldownDuration(), vm.parseJsonUint(inputJson, ".initialSwapCooldownDuration"));
        assertFalse(module.paused());
        assertFalse(module.suspendedByProvider());
    }

    function _assertAMFunctionRoles(
        address accessManager,
        MakinaXInfra memory infra,
        uint16[] memory bridgeIds,
        address[] memory bridgeEncoders
    ) internal view {
        // Transparent proxy admins' upgradeAndCall is guarded by INFRA_UPGRADE_ROLE
        assertEq(
            IAccessManager(accessManager)
                .getTargetFunctionRole(getProxyAdmin(accessManager), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
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

        // MakinaXRegistry component setters are guarded by INFRA_UPGRADE_ROLE
        bytes4[4] memory registryComponentSelectors = [
            MakinaXRegistry.setModuleFactory.selector,
            MakinaXRegistry.setModuleImplementation.selector,
            MakinaXRegistry.setFlashLoanModule.selector,
            MakinaXRegistry.setBridgeEncoder.selector
        ];
        for (uint256 i; i < registryComponentSelectors.length; ++i) {
            assertEq(
                IAccessManager(accessManager)
                    .getTargetFunctionRole(address(infra.registry), registryComponentSelectors[i]),
                Roles.INFRA_UPGRADE_ROLE
            );
        }

        // MakinaXRegistry fee collector setter is guarded by INFRA_CONFIG_ROLE
        assertEq(
            IAccessManager(accessManager)
                .getTargetFunctionRole(address(infra.registry), MakinaXRegistry.setFeeCollector.selector),
            Roles.INFRA_CONFIG_ROLE
        );

        // ModuleFactory deployment functions are guarded by STRATEGY_DEPLOYMENT_ROLE
        bytes4[2] memory factoryDeploySelectors =
            [ModuleFactory.createModule.selector, ModuleFactory.setFreeDeployment.selector];
        for (uint256 i; i < factoryDeploySelectors.length; ++i) {
            assertEq(
                IAccessManager(accessManager)
                    .getTargetFunctionRole(address(infra.moduleFactory), factoryDeploySelectors[i]),
                Roles.STRATEGY_DEPLOYMENT_ROLE
            );
        }

        // ModuleFactory config setters are guarded by INFRA_CONFIG_ROLE
        bytes4[2] memory factoryConfigSelectors =
            [ModuleFactory.setDefaultProvider.selector, ModuleFactory.setDefaultSwapFeeRate.selector];
        for (uint256 i; i < factoryConfigSelectors.length; ++i) {
            assertEq(
                IAccessManager(accessManager)
                    .getTargetFunctionRole(address(infra.moduleFactory), factoryConfigSelectors[i]),
                Roles.INFRA_CONFIG_ROLE
            );
        }

        // Every deployed bridge encoder is guarded as well
        for (uint256 i; i < bridgeIds.length; ++i) {
            _assertBridgeEncoderAMRoles(accessManager, bridgeIds[i], bridgeEncoders[i]);
        }
    }

    function _assertAMRoleGrants(address accessManager, string memory inputJson) internal view {
        uint64 adminRole = 0;

        // The super admin is granted ADMIN_ROLE with the configured execution delay
        address superAdmin = vm.parseJsonAddress(inputJson, ".superAdminRoleGrant.account");
        uint32 superAdminDelay = uint32(vm.parseJsonUint(inputJson, ".superAdminRoleGrant.executionDelay"));
        (bool isMember, uint32 executionDelay) = IAccessManager(accessManager).hasRole(adminRole, superAdmin);
        assertTrue(isMember);
        assertEq(executionDelay, superAdminDelay);

        // The other role grants are applied
        uint256 len;
        while (vm.keyExistsJson(inputJson, string.concat(".otherRoleGrants[", vm.toString(len), "]"))) {
            string memory base = string.concat(".otherRoleGrants[", vm.toString(len), "]");
            uint64 roleId = uint64(vm.parseJsonUint(inputJson, string.concat(base, ".roleId")));
            address account = vm.parseJsonAddress(inputJson, string.concat(base, ".account"));
            uint32 expectedDelay = uint32(vm.parseJsonUint(inputJson, string.concat(base, ".executionDelay")));
            (isMember, executionDelay) = IAccessManager(accessManager).hasRole(roleId, account);
            assertTrue(isMember);
            assertEq(executionDelay, expectedDelay);
            ++len;
        }
        assertTrue(len > 0);

        // The deployer no longer holds ADMIN_ROLE
        (isMember,) = IAccessManager(accessManager).hasRole(adminRole, deployMakinaX.deployer());
        assertFalse(isMember);
    }

    function _assertBridgeEncoderAMRoles(address accessManager, uint16 bridgeId, address encoder) internal view {
        // The encoder's transparent proxy admin upgradeAndCall is guarded by INFRA_UPGRADE_ROLE
        assertEq(
            IAccessManager(accessManager)
                .getTargetFunctionRole(getProxyAdmin(encoder), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );

        bytes4[] memory encoderSetterSelectors;
        if (bridgeId == ACROSS_V4_BRIDGE_ID) {
            encoderSetterSelectors = new bytes4[](2);
            encoderSetterSelectors[0] = AcrossV4BridgeEncoder.addRoute.selector;
            encoderSetterSelectors[1] = AcrossV4BridgeEncoder.removeRoute.selector;
        } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
            encoderSetterSelectors = new bytes4[](3);
            encoderSetterSelectors[0] = LayerZeroV2BridgeEncoder.setLzEndpointId.selector;
            encoderSetterSelectors[1] = LayerZeroV2BridgeEncoder.addOft.selector;
            encoderSetterSelectors[2] = LayerZeroV2BridgeEncoder.removeOft.selector;
        } else if (bridgeId == CCTP_V2_BRIDGE_ID) {
            encoderSetterSelectors = new bytes4[](1);
            encoderSetterSelectors[0] = CctpV2BridgeEncoder.setCctpDomain.selector;
        } else {
            revert("unsupported bridgeId in test fixture");
        }

        // The encoder setters are guarded by INFRA_CONFIG_ROLE
        for (uint256 i; i < encoderSetterSelectors.length; ++i) {
            assertEq(
                IAccessManager(accessManager).getTargetFunctionRole(encoder, encoderSetterSelectors[i]),
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

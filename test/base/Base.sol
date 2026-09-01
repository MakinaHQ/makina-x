// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {AcrossV4BridgeEncoder} from "../../src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "../../src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {IntegrationIds} from "../utils/IntegrationIds.sol";
import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {LayerZeroV2BridgeEncoder} from "../../src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";
import {MakinaXModule} from "../../src/MakinaXModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {IRCodeReader} from "../utils/IRCodeReader.sol";
import {ProxyUtils} from "../utils/ProxyUtils.sol";
import {Roles} from "../utils/Roles.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";

abstract contract Base is IRCodeReader, ProxyUtils, SaltDomains, IntegrationIds {
    struct MakinaXInfra {
        AccessManagerUpgradeable accessManager;
        MakinaXRegistry registry;
        ModuleFactory moduleFactory;
        address makinaXModuleImplem;
        FlashLoanModule flashLoanModule;
    }

    struct AMRoleGrant {
        uint64 roleId;
        address account;
        uint32 executionDelay;
    }

    struct FlashLoanProviders {
        address morpho;
    }

    function deployMakinaXInfra(
        address _initialAMAdmin,
        FlashLoanProviders memory flProviders,
        address _defaultProvider,
        uint256 _defaultSwapFeeRate,
        bool _freeDeployment
    ) internal returns (MakinaXInfra memory deployment) {
        deployment.accessManager = _deployAccessManager(_initialAMAdmin, _initialAMAdmin);
        address weirollVM = _deployWeirollVM();
        deployment.registry =
            _deployMakinaXRegistry(address(deployment.accessManager), address(deployment.accessManager));
        deployment.moduleFactory = _deployModuleFactory(
            address(deployment.accessManager),
            address(deployment.accessManager),
            address(deployment.registry),
            _defaultProvider,
            _defaultSwapFeeRate,
            _freeDeployment
        );
        deployment.makinaXModuleImplem = _deployMakinaXModuleImplem(address(deployment.registry), weirollVM);
        deployment.flashLoanModule = _deployFlashLoanModule(address(deployment.moduleFactory), flProviders);
    }

    function setupMakinaXRegistry(
        MakinaXInfra memory deployment,
        address feeCollector,
        uint16[] memory bridgeIds,
        address[] memory encoders
    ) internal {
        require(bridgeIds.length == encoders.length, "bridge encoders length mismatch");

        deployment.registry.setModuleFactory(address(deployment.moduleFactory));
        deployment.registry.setModuleImplementation(deployment.makinaXModuleImplem);
        deployment.registry.setFeeCollector(feeCollector);
        deployment.registry.setFlashLoanModule(address(deployment.flashLoanModule));

        for (uint256 i; i < bridgeIds.length; ++i) {
            deployment.registry.setBridgeEncoder(bridgeIds[i], encoders[i]);
        }
    }

    function setupAMFunctionRoles(MakinaXInfra memory deployment, uint16[] memory bridgeIds, address[] memory encoders)
        internal
    {
        require(bridgeIds.length == encoders.length, "bridge encoders length mismatch");

        AccessManagerUpgradeable accessManager = deployment.accessManager;

        // Transparent Proxy Admins
        bytes4[] memory proxyAdminSelectors = _proxyAdminAMSelectors();
        accessManager.setTargetFunctionRole(
            getProxyAdmin(address(accessManager)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
        );
        accessManager.setTargetFunctionRole(
            getProxyAdmin(address(deployment.registry)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
        );
        accessManager.setTargetFunctionRole(
            getProxyAdmin(address(deployment.moduleFactory)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
        );

        // MakinaXRegistry component setters
        bytes4[] memory registryComponentSelectors = new bytes4[](4);
        registryComponentSelectors[0] = MakinaXRegistry.setModuleFactory.selector;
        registryComponentSelectors[1] = MakinaXRegistry.setModuleImplementation.selector;
        registryComponentSelectors[2] = MakinaXRegistry.setFlashLoanModule.selector;
        registryComponentSelectors[3] = MakinaXRegistry.setBridgeEncoder.selector;
        accessManager.setTargetFunctionRole(
            address(deployment.registry), registryComponentSelectors, Roles.INFRA_UPGRADE_ROLE
        );

        // MakinaXRegistry fee collector setter
        bytes4[] memory registryConfigSelectors = new bytes4[](1);
        registryConfigSelectors[0] = MakinaXRegistry.setFeeCollector.selector;
        accessManager.setTargetFunctionRole(
            address(deployment.registry), registryConfigSelectors, Roles.INFRA_CONFIG_ROLE
        );

        // ModuleFactory deployment functions
        bytes4[] memory factoryDeploySelectors = new bytes4[](2);
        factoryDeploySelectors[0] = ModuleFactory.createModule.selector;
        factoryDeploySelectors[1] = ModuleFactory.setFreeDeployment.selector;
        accessManager.setTargetFunctionRole(
            address(deployment.moduleFactory), factoryDeploySelectors, Roles.STRATEGY_DEPLOYMENT_ROLE
        );

        // ModuleFactory config setters
        bytes4[] memory factoryConfigSelectors = new bytes4[](2);
        factoryConfigSelectors[0] = ModuleFactory.setDefaultProvider.selector;
        factoryConfigSelectors[1] = ModuleFactory.setDefaultSwapFeeRate.selector;
        accessManager.setTargetFunctionRole(
            address(deployment.moduleFactory), factoryConfigSelectors, Roles.INFRA_CONFIG_ROLE
        );

        // Bridge encoders
        for (uint256 i; i < bridgeIds.length; ++i) {
            accessManager.setTargetFunctionRole(
                getProxyAdmin(encoders[i]), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
            );
            accessManager.setTargetFunctionRole(
                encoders[i], _bridgeEncoderAMSelectors(bridgeIds[i]), Roles.INFRA_CONFIG_ROLE
            );
        }
    }

    function setupAccessManagerRoles(
        AccessManagerUpgradeable accessManager,
        AMRoleGrant memory superAdminRoleGrant,
        AMRoleGrant[] memory otherRoleGrants,
        address deployer
    ) internal {
        uint64 adminRole = accessManager.ADMIN_ROLE();

        // Grant non-super-admin roles
        for (uint256 i; i < otherRoleGrants.length; ++i) {
            _grantRole(accessManager, otherRoleGrants[i]);
        }

        // set guardian role for of all other non-super-admin roles
        accessManager.setRoleGuardian(Roles.STRATEGY_DEPLOYMENT_ROLE, Roles.GUARDIAN_ROLE);
        accessManager.setRoleGuardian(Roles.INFRA_CONFIG_ROLE, Roles.GUARDIAN_ROLE);
        accessManager.setRoleGuardian(Roles.INFRA_UPGRADE_ROLE, Roles.GUARDIAN_ROLE);

        // Grant super admin role
        _grantRole(accessManager, superAdminRoleGrant);

        // Revoke super admin role from the deployer
        if (deployer != superAdminRoleGrant.account) {
            accessManager.revokeRole(adminRole, deployer);
        }
    }

    function transferAccessManagerOwnership(AccessManagerUpgradeable accessManager) internal {
        Ownable(getProxyAdmin(address(accessManager))).transferOwnership(address(accessManager));
    }

    ///
    /// ACCESS MANAGER INFRA UTILS
    ///

    function _bridgeEncoderAMSelectors(uint16 bridgeId) internal pure returns (bytes4[] memory selectors) {
        if (bridgeId == ACROSS_V4_BRIDGE_ID) {
            selectors = new bytes4[](2);
            selectors[0] = AcrossV4BridgeEncoder.addRoute.selector;
            selectors[1] = AcrossV4BridgeEncoder.removeRoute.selector;
        } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
            selectors = new bytes4[](3);
            selectors[0] = LayerZeroV2BridgeEncoder.setLzEndpointId.selector;
            selectors[1] = LayerZeroV2BridgeEncoder.addOft.selector;
            selectors[2] = LayerZeroV2BridgeEncoder.removeOft.selector;
        } else if (bridgeId == CCTP_V2_BRIDGE_ID) {
            selectors = new bytes4[](1);
            selectors[0] = CctpV2BridgeEncoder.setCctpDomain.selector;
        } else {
            revert("Base: unsupported bridgeId");
        }
    }

    function _proxyAdminAMSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = ProxyAdmin.upgradeAndCall.selector;
    }

    function _grantRole(AccessManagerUpgradeable accessManager, AMRoleGrant memory roleGrant) private {
        require(roleGrant.account != address(0), "zero roleGrant account address");
        accessManager.grantRole(roleGrant.roleId, roleGrant.account, roleGrant.executionDelay);
    }

    ///
    /// DEPLOYMENT UTILS
    ///

    function _deployAccessManager(address _initialAMAdmin, address _proxyOwner)
        internal
        returns (AccessManagerUpgradeable accessManager)
    {
        address implem = _deployCode(type(AccessManagerUpgradeable).creationCode, 0);
        return AccessManagerUpgradeable(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(AccessManagerUpgradeable.initialize, (_initialAMAdmin))
                    )
                ),
                ACCESS_MANAGER_SALT_DOMAIN
            )
        );
    }

    function _deployWeirollVM() internal returns (address weirollVM) {
        return _deployCode(getWeirollVMCode(), WEIROLL_VM_SALT_DOMAIN);
    }

    function _deployMakinaXRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (MakinaXRegistry registry)
    {
        address implem = _deployCode(type(MakinaXRegistry).creationCode, 0);
        return MakinaXRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(MakinaXRegistry.initialize, (_accessManager)))
                ),
                MAKINA_X_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployModuleFactory(
        address _proxyOwner,
        address _accessManager,
        address _registry,
        address _defaultProvider,
        uint256 _defaultSwapFeeRate,
        bool _freeDeployment
    ) internal returns (ModuleFactory moduleFactory) {
        address implem = _deployCode(abi.encodePacked(type(ModuleFactory).creationCode, abi.encode(_registry)), 0);
        return ModuleFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem,
                        _proxyOwner,
                        abi.encodeCall(
                            ModuleFactory.initialize,
                            (_accessManager, _defaultProvider, _defaultSwapFeeRate, _freeDeployment)
                        )
                    )
                ),
                MODULE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deployMakinaXModuleImplem(address _registry, address _weirollVM) internal returns (address implem) {
        return _deployCode(
            abi.encodePacked(type(MakinaXModule).creationCode, abi.encode(_registry, _weirollVM)),
            MAKINA_X_MODULE_IMPLEM_SALT_DOMAIN
        );
    }

    function _deployFlashLoanModule(address _moduleFactory, FlashLoanProviders memory flProviders)
        internal
        returns (FlashLoanModule flashLoanModule)
    {
        return FlashLoanModule(
            _deployCode(
                abi.encodePacked(type(FlashLoanModule).creationCode, abi.encode(_moduleFactory, flProviders.morpho)),
                FLASHLOAN_MODULE_SALT_DOMAIN
            )
        );
    }

    function _deployAcrossV4BridgeEncoder(address _proxyOwner, address _accessManager, address _acrossV4SpokePool)
        internal
        returns (AcrossV4BridgeEncoder acrossV4BridgeEncoder)
    {
        address implem =
            _deployCode(abi.encodePacked(type(AcrossV4BridgeEncoder).creationCode, abi.encode(_acrossV4SpokePool)), 0);
        return AcrossV4BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(AcrossV4BridgeEncoder.initialize, (_accessManager)))
                ),
                ACROSS_V4_BRIDGE_ENCODER_SALT_DOMAIN
            )
        );
    }

    function _deployLayerZeroV2BridgeEncoder(address _proxyOwner, address _accessManager)
        internal
        returns (LayerZeroV2BridgeEncoder layerZeroV2BridgeEncoder)
    {
        address implem = _deployCode(type(LayerZeroV2BridgeEncoder).creationCode, 0);
        return LayerZeroV2BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(LayerZeroV2BridgeEncoder.initialize, (_accessManager))
                    )
                ),
                LAYER_ZERO_V2_BRIDGE_ENCODER_SALT_DOMAIN
            )
        );
    }

    function _deployCctpV2BridgeEncoder(address _proxyOwner, address _accessManager, address cctpV2TokenMessenger)
        internal
        returns (CctpV2BridgeEncoder cctpV2BridgeEncoder)
    {
        address implem =
            _deployCode(abi.encodePacked(type(CctpV2BridgeEncoder).creationCode, abi.encode(cctpV2TokenMessenger)), 0);
        return CctpV2BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(CctpV2BridgeEncoder.initialize, (_accessManager)))
                ),
                CCTP_V2_BRIDGE_ENCODER_SALT_DOMAIN
            )
        );
    }

    function _deployCode(bytes memory bytecode, bytes32) internal virtual returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(addr != address(0), "Deployment failed");

        return addr;
    }
}

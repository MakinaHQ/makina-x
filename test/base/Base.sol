// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {AcrossV4BridgeEncoder} from "../../src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "../../src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {IntegrationIds} from "../utils/IntegrationIds.sol";
import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {LayerZeroV2BridgeEncoder} from "../../src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";
import {MakinaLiteModule} from "../../src/MakinaLiteModule.sol";
import {MakinaLiteRegistry} from "../../src/registry/MakinaLiteRegistry.sol";
import {ProxyUtils} from "../utils/ProxyUtils.sol";
import {Roles} from "../utils/Roles.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";

abstract contract Base is ProxyUtils, SaltDomains, IntegrationIds {
    struct MakinaLiteInfra {
        MakinaLiteRegistry registry;
        ModuleFactory moduleFactory;
        address makinaLiteModuleImplem;
        FlashLoanModule flashLoanModule;
    }

    struct FlashLoanProviders {
        address morpho;
    }

    function deployMakinaLiteInfra(address _accessManager, address _weirollVM, FlashLoanProviders memory flProviders)
        internal
        returns (MakinaLiteInfra memory deployment)
    {
        deployment.registry = _deployMakinaLiteRegistry(_accessManager, _accessManager);
        deployment.moduleFactory = _deployModuleFactory(_accessManager, _accessManager, address(deployment.registry));
        deployment.makinaLiteModuleImplem = _deployMakinaLiteModuleImplem(address(deployment.registry), _weirollVM);
        deployment.flashLoanModule = _deployFlashLoanModule(address(deployment.moduleFactory), flProviders);
    }

    function setupMakinaLiteRegistry(MakinaLiteInfra memory deployment, address feeCollector) internal {
        deployment.registry.setModuleFactory(address(deployment.moduleFactory));
        deployment.registry.setModuleImplementation(deployment.makinaLiteModuleImplem);
        deployment.registry.setFeeCollector(feeCollector);
        deployment.registry.setFlashLoanModule(address(deployment.flashLoanModule));
    }

    function setupAMFunctionRoles(address accessManager, MakinaLiteInfra memory deployment) internal {
        // Transparent Proxy Admins
        bytes4[] memory proxyAdminSelectors = new bytes4[](1);
        proxyAdminSelectors[0] = ProxyAdmin.upgradeAndCall.selector;

        IAccessManager(accessManager)
            .setTargetFunctionRole(
                getProxyAdmin(address(deployment.registry)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
            );
        IAccessManager(accessManager)
            .setTargetFunctionRole(
                getProxyAdmin(address(deployment.moduleFactory)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE
            );

        // MakinaLiteRegistry setters
        bytes4[] memory registrySetterSelectors = new bytes4[](5);
        registrySetterSelectors[0] = MakinaLiteRegistry.setModuleFactory.selector;
        registrySetterSelectors[1] = MakinaLiteRegistry.setModuleImplementation.selector;
        registrySetterSelectors[2] = MakinaLiteRegistry.setFeeCollector.selector;
        registrySetterSelectors[3] = MakinaLiteRegistry.setFlashLoanModule.selector;
        registrySetterSelectors[4] = MakinaLiteRegistry.setBridgeEncoder.selector;
        IAccessManager(accessManager)
            .setTargetFunctionRole(address(deployment.registry), registrySetterSelectors, Roles.INFRA_CONFIG_ROLE);

        // ModuleFactory setters
        bytes4[] memory factorySetterSelectors = new bytes4[](1);
        factorySetterSelectors[0] = ModuleFactory.createModule.selector;
    }

    function _deployMakinaLiteRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (MakinaLiteRegistry registry)
    {
        address implem = _deployCode(type(MakinaLiteRegistry).creationCode, 0);
        return MakinaLiteRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(MakinaLiteRegistry.initialize, (_accessManager)))
                ),
                MAKINA_LITE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployModuleFactory(address _proxyOwner, address _accessManager, address _registry)
        internal
        returns (ModuleFactory moduleFactory)
    {
        address implem = _deployCode(abi.encodePacked(type(ModuleFactory).creationCode, abi.encode(_registry)), 0);
        return ModuleFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(ModuleFactory.initialize, (_accessManager)))
                ),
                MODULE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deployMakinaLiteModuleImplem(address _registry, address _weirollVM) internal returns (address implem) {
        return _deployCode(
            abi.encodePacked(type(MakinaLiteModule).creationCode, abi.encode(_registry, _weirollVM)),
            MAKINA_LITE_MODULE_IMPLEM_SALT_DOMAIN
        );
    }

    function _deployFlashLoanModule(address _moduleFactory, FlashLoanProviders memory flProviders)
        internal
        returns (FlashLoanModule flashLoanModule)
    {
        return FlashLoanModule(
            _deployCode(
                abi.encodePacked(type(FlashLoanModule).creationCode, abi.encode(_moduleFactory, flProviders.morpho)),
                FLASH_LOAN_MODULE_SALT_DOMAIN
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

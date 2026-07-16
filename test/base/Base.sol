// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {AcrossV4BridgeEncoder} from "../../src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "../../src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {IntegrationIds} from "../utils/IntegrationIds.sol";
import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {LayerZeroV2BridgeEncoder} from "../../src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";
import {MakinaXModule} from "../../src/MakinaXModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {ProxyUtils} from "../utils/ProxyUtils.sol";
import {Roles} from "../utils/Roles.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";

abstract contract Base is ProxyUtils, SaltDomains, IntegrationIds {
    struct MakinaXInfra {
        MakinaXRegistry registry;
        ModuleFactory moduleFactory;
        address makinaXModuleImplem;
        FlashLoanModule flashLoanModule;
    }

    struct FlashLoanProviders {
        address morpho;
    }

    struct Call {
        address target;
        bytes data;
    }

    function deployMakinaXInfra(
        address _accessManager,
        address _weirollVM,
        FlashLoanProviders memory flProviders,
        address _defaultProvider,
        uint256 _defaultSwapFeeRate,
        bool _freeDeployment
    ) internal returns (MakinaXInfra memory deployment) {
        deployment.registry = _deployMakinaXRegistry(_accessManager, _accessManager);
        deployment.moduleFactory = _deployModuleFactory(
            _accessManager,
            _accessManager,
            address(deployment.registry),
            _defaultProvider,
            _defaultSwapFeeRate,
            _freeDeployment
        );
        deployment.makinaXModuleImplem = _deployMakinaXModuleImplem(address(deployment.registry), _weirollVM);
        deployment.flashLoanModule = _deployFlashLoanModule(address(deployment.moduleFactory), flProviders);
    }

    function setupMakinaXRegistry(MakinaXInfra memory deployment, address feeCollector) internal {
        _executeCalls(_registrySetupCalls(deployment, feeCollector));
    }

    function setupAMFunctionRoles(address accessManager, MakinaXInfra memory deployment) internal {
        _executeCalls(_amFunctionRoleCalls(accessManager, deployment));
    }

    ///
    /// ACCESS MANAGER INFRA UTILS
    ///

    /// @dev Returns the calls that configure the MakinaXRegistry component addresses.
    function _registrySetupCalls(MakinaXInfra memory deployment, address feeCollector)
        internal
        pure
        returns (Call[] memory calls)
    {
        address registry = address(deployment.registry);

        calls = new Call[](4);
        calls[0] = Call(registry, abi.encodeCall(MakinaXRegistry.setModuleFactory, (address(deployment.moduleFactory))));
        calls[1] =
            Call(registry, abi.encodeCall(MakinaXRegistry.setModuleImplementation, (deployment.makinaXModuleImplem)));
        calls[2] = Call(registry, abi.encodeCall(MakinaXRegistry.setFeeCollector, (feeCollector)));
        calls[3] =
            Call(registry, abi.encodeCall(MakinaXRegistry.setFlashLoanModule, (address(deployment.flashLoanModule))));
    }

    /// @dev Returns the AccessManager calls that assign function roles for the MakinaX infrastructure.
    function _amFunctionRoleCalls(address accessManager, MakinaXInfra memory deployment)
        internal
        view
        returns (Call[] memory calls)
    {
        // Transparent Proxy Admins
        bytes4[] memory proxyAdminSelectors = new bytes4[](1);
        proxyAdminSelectors[0] = ProxyAdmin.upgradeAndCall.selector;

        // MakinaXRegistry setters
        bytes4[] memory registrySetterSelectors = new bytes4[](5);
        registrySetterSelectors[0] = MakinaXRegistry.setModuleFactory.selector;
        registrySetterSelectors[1] = MakinaXRegistry.setModuleImplementation.selector;
        registrySetterSelectors[2] = MakinaXRegistry.setFeeCollector.selector;
        registrySetterSelectors[3] = MakinaXRegistry.setFlashLoanModule.selector;
        registrySetterSelectors[4] = MakinaXRegistry.setBridgeEncoder.selector;

        // ModuleFactory deployment selector
        bytes4[] memory factoryDeploySelectors = new bytes4[](1);
        factoryDeploySelectors[0] = ModuleFactory.createModule.selector;

        // ModuleFactory config setters
        bytes4[] memory factoryConfigSelectors = new bytes4[](3);
        factoryConfigSelectors[0] = ModuleFactory.setDefaultProvider.selector;
        factoryConfigSelectors[1] = ModuleFactory.setDefaultSwapFeeRate.selector;
        factoryConfigSelectors[2] = ModuleFactory.setFreeDeployment.selector;

        calls = new Call[](5);
        calls[0] = Call(
            accessManager,
            abi.encodeCall(
                IAccessManager.setTargetFunctionRole,
                (getProxyAdmin(address(deployment.registry)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE)
            )
        );
        calls[1] = Call(
            accessManager,
            abi.encodeCall(
                IAccessManager.setTargetFunctionRole,
                (getProxyAdmin(address(deployment.moduleFactory)), proxyAdminSelectors, Roles.INFRA_UPGRADE_ROLE)
            )
        );
        calls[2] = Call(
            accessManager,
            abi.encodeCall(
                IAccessManager.setTargetFunctionRole,
                (address(deployment.registry), registrySetterSelectors, Roles.INFRA_CONFIG_ROLE)
            )
        );
        calls[3] = Call(
            accessManager,
            abi.encodeCall(
                IAccessManager.setTargetFunctionRole,
                (address(deployment.moduleFactory), factoryDeploySelectors, Roles.STRATEGY_DEPLOYMENT_ROLE)
            )
        );
        calls[4] = Call(
            accessManager,
            abi.encodeCall(
                IAccessManager.setTargetFunctionRole,
                (address(deployment.moduleFactory), factoryConfigSelectors, Roles.INFRA_CONFIG_ROLE)
            )
        );
    }

    function _executeCalls(Call[] memory calls) internal {
        for (uint256 i; i < calls.length; ++i) {
            Address.functionCall(calls[i].target, calls[i].data);
        }
    }

    ///
    /// DEPLOYMENT UTILS
    ///

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

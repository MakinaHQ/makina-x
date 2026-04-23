// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossV4BridgeEncoder} from "../../src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "../../src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {IntegrationIds} from "../utils/IntegrationIds.sol";
import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {LayerZeroV2BridgeEncoder} from "../../src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";
import {MakinaLiteModule} from "../../src/MakinaLiteModule.sol";
import {MakinaLiteRegistry} from "../../src/registry/MakinaLiteRegistry.sol";

abstract contract Base is IntegrationIds {
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

    function _deployMakinaLiteRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (MakinaLiteRegistry registry)
    {
        address implem = _deployCode(type(MakinaLiteRegistry).creationCode);
        return MakinaLiteRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(MakinaLiteRegistry.initialize, (_accessManager)))
                )
            )
        );
    }

    function _deployModuleFactory(address _proxyOwner, address _accessManager, address _registry)
        internal
        returns (ModuleFactory moduleFactory)
    {
        address implem = _deployCode(abi.encodePacked(type(ModuleFactory).creationCode, abi.encode(_registry)));
        return ModuleFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(ModuleFactory.initialize, (_accessManager)))
                )
            )
        );
    }

    function _deployMakinaLiteModuleImplem(address _registry, address _weirollVM) internal returns (address implem) {
        return _deployCode(abi.encodePacked(type(MakinaLiteModule).creationCode, abi.encode(_registry, _weirollVM)));
    }

    function _deployFlashLoanModule(address _moduleFactory, FlashLoanProviders memory flProviders)
        internal
        returns (FlashLoanModule flashLoanModule)
    {
        return FlashLoanModule(
            _deployCode(
                abi.encodePacked(type(FlashLoanModule).creationCode, abi.encode(_moduleFactory, flProviders.morpho))
            )
        );
    }

    function _deployAcrossV4BridgeEncoder(address _proxyOwner, address _accessManager, address _acrossV4SpokePool)
        internal
        returns (AcrossV4BridgeEncoder acrossV4BridgeEncoder)
    {
        address implem =
            _deployCode(abi.encodePacked(type(AcrossV4BridgeEncoder).creationCode, abi.encode(_acrossV4SpokePool)));
        return AcrossV4BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(AcrossV4BridgeEncoder.initialize, (_accessManager)))
                )
            )
        );
    }

    function _deployLayerZeroV2BridgeEncoder(address _proxyOwner, address _accessManager)
        internal
        returns (LayerZeroV2BridgeEncoder layerZeroV2BridgeEncoder)
    {
        address implem = _deployCode(type(LayerZeroV2BridgeEncoder).creationCode);
        return LayerZeroV2BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(LayerZeroV2BridgeEncoder.initialize, (_accessManager))
                    )
                )
            )
        );
    }

    function _deployCctpV2BridgeEncoder(address _proxyOwner, address _accessManager, address cctpV2TokenMessenger)
        internal
        returns (CctpV2BridgeEncoder cctpV2BridgeEncoder)
    {
        address implem =
            _deployCode(abi.encodePacked(type(CctpV2BridgeEncoder).creationCode, abi.encode(cctpV2TokenMessenger)));
        return CctpV2BridgeEncoder(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(CctpV2BridgeEncoder.initialize, (_accessManager)))
                )
            )
        );
    }

    function _deployCode(bytes memory bytecode) internal virtual returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(addr != address(0), "Deployment failed");

        return addr;
    }
}

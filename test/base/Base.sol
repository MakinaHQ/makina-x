// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MakinaLiteRegistry} from "../../src/registry/MakinaLiteRegistry.sol";

abstract contract Base {
    struct MakinaLiteInfra {
        MakinaLiteRegistry registry;
    }

    function deployMakinaLiteInfra(address _accessManager) internal returns (MakinaLiteInfra memory deployment) {
        deployment.registry = _deployMakinaLiteRegistry(_accessManager, _accessManager);
    }

    function setupMakinaLiteRegistry(MakinaLiteInfra memory deployment, address feeCollector) internal {
        deployment.registry.setFeeCollector(feeCollector);
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

    function _deployCode(bytes memory bytecode) internal virtual returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(addr != address(0), "Deployment failed");

        return addr;
    }
}

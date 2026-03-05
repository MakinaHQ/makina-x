// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Constants} from "../utils/Constants.sol";
import {MakinaLiteRegistry} from "../../src/registry/MakinaLiteRegistry.sol";
import {MockSafe} from "../mocks/MockSafe.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, Constants, Test {
    address internal deployer;

    address internal dao;
    address internal operator;
    address internal guardian;

    MockSafe internal safe;

    AccessManagerUpgradeable internal accessManager;

    MakinaLiteRegistry internal registry;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");

        _deployAccessManager(deployer, deployer);

        safe = new MockSafe();

        MakinaLiteInfra memory makinaLiteInfra = deployMakinaLiteInfra(address(accessManager));
        registry = makinaLiteInfra.registry;

        setupMakinaLiteRegistry(makinaLiteInfra, dao);

        setupAccessManagerRoles();
    }

    ///
    /// INFRA UTILS
    ///

    function setupAccessManagerRoles() internal {
        // Grant roles to the relevant accounts
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);

        // Revoke roles from the deployer
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(deployer));
    }

    function _deployAccessManager(address _initialAMAdmin, address _proxyOwner) internal {
        address implem = _deployCode(type(AccessManagerUpgradeable).creationCode);
        accessManager = AccessManagerUpgradeable(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(AccessManagerUpgradeable.initialize, (_initialAMAdmin))
                    )
                )
            )
        );
    }
}

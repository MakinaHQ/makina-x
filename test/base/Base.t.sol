// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import "forge-std/Test.sol";

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {Constants} from "../utils/Constants.sol";
import {FlashLoanModule} from "src/flash-loans/FlashLoanModule.sol";
import {IRCodeReader} from "../utils/IRCodeReader.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {MockMorpho} from "../mocks/MockMorpho.sol";
import {MockSafe} from "../mocks/MockSafe.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, IRCodeReader, Constants, Test {
    address internal deployer;

    address internal dao;
    address internal operator;
    address internal guardian;

    MockMorpho internal morpho;

    MockSafe internal safe;

    AccessManagerUpgradeable internal accessManager;

    address internal weirollVM;

    MakinaXRegistry internal registry;
    ModuleFactory internal moduleFactory;
    address internal makinaXModuleImplem;
    FlashLoanModule internal flashLoanModule;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");

        morpho = new MockMorpho();

        _deployWeirollVM();

        safe = new MockSafe();

        MakinaXInfra memory makinaXInfra = deployMakinaXInfra(
            deployer, weirollVM, FlashLoanProviders({morpho: address(morpho)}), dao, DEFAULT_SWAP_FEE_RATE, false
        );
        accessManager = makinaXInfra.accessManager;
        registry = makinaXInfra.registry;
        moduleFactory = makinaXInfra.moduleFactory;
        makinaXModuleImplem = makinaXInfra.makinaXModuleImplem;
        flashLoanModule = makinaXInfra.flashLoanModule;

        setupMakinaXRegistry(makinaXInfra, dao, new uint16[](0), new address[](0));

        setupAccessManagerRoles(
            accessManager, AMRoleGrant({roleId: 0, account: dao, executionDelay: 0}), new AMRoleGrant[](0), deployer
        );
    }

    ///
    /// INFRA UTILS
    ///

    function _deployWeirollVM() internal {
        weirollVM = _deployCode(getWeirollVMCode(), 0);
    }
}

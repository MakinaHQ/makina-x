// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IModuleFactory} from "src/interfaces/IModuleFactory.sol";
import {ModuleFactory} from "src/factory/ModuleFactory.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract Initialize_ModuleFactory_Unit_Concrete_Test is Unit_Concrete_Test {
    uint256 internal constant MAX_FEE_RATE = 1e18;

    function test_RevertWhen_FeeRateTooHigh() public {
        address implem = address(new ModuleFactory(address(registry)));
        bytes memory initData =
            abi.encodeCall(ModuleFactory.initialize, (address(accessManager), address(0), MAX_FEE_RATE + 1, false));

        vm.expectRevert(Errors.InvalidFeeRate.selector);
        new TransparentUpgradeableProxy(implem, dao, initData);
    }

    function test_Initialize() public {
        address provider = makeAddr("provider");
        uint256 feeRate = 0.01e18;

        address implem = address(new ModuleFactory(address(registry)));
        bytes memory initData =
            abi.encodeCall(ModuleFactory.initialize, (address(accessManager), provider, feeRate, true));

        ModuleFactory factory = ModuleFactory(address(new TransparentUpgradeableProxy(implem, dao, initData)));

        assertEq(factory.defaultProvider(), provider);
        assertEq(factory.defaultSwapFeeRate(), feeRate);
        assertTrue(factory.freeDeployment());
    }
}

contract Getters_Setters_ModuleFactory_Unit_Concrete_Test is Unit_Concrete_Test {
    uint256 internal constant MAX_FEE_RATE = 1e18;

    function test_Getters() public view {
        assertEq(moduleFactory.registry(), address(registry));
        assertTrue(moduleFactory.isMakinaXModule(address(makinaXModule)));
        assertEq(moduleFactory.defaultProvider(), dao);
        assertEq(moduleFactory.defaultSwapFeeRate(), DEFAULT_SWAP_FEE_RATE);
        assertFalse(moduleFactory.freeDeployment());
    }

    function test_SetDefaultProvider_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        moduleFactory.setDefaultProvider(address(1));
    }

    function test_SetDefaultProvider() public {
        address newProvider = makeAddr("newProvider");

        vm.expectEmit(true, true, false, false, address(moduleFactory));
        emit IModuleFactory.DefaultProviderChanged(dao, newProvider);

        vm.prank(dao);
        moduleFactory.setDefaultProvider(newProvider);

        assertEq(moduleFactory.defaultProvider(), newProvider);
    }

    function test_SetDefaultSwapFeeRate_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        moduleFactory.setDefaultSwapFeeRate(0);
    }

    function test_SetDefaultSwapFeeRate_RevertWhen_FeeRateTooHigh() public {
        vm.prank(dao);
        vm.expectRevert(Errors.InvalidFeeRate.selector);
        moduleFactory.setDefaultSwapFeeRate(MAX_FEE_RATE + 1);
    }

    function test_SetDefaultSwapFeeRate() public {
        vm.expectEmit(false, false, false, true, address(moduleFactory));
        emit IModuleFactory.DefaultSwapFeeRateChanged(DEFAULT_SWAP_FEE_RATE, MAX_FEE_RATE);

        vm.prank(dao);
        moduleFactory.setDefaultSwapFeeRate(MAX_FEE_RATE);

        assertEq(moduleFactory.defaultSwapFeeRate(), MAX_FEE_RATE);
    }

    function test_SetFreeDeployment_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        moduleFactory.setFreeDeployment(true);
    }

    function test_SetFreeDeployment() public {
        vm.expectEmit(false, false, false, true, address(moduleFactory));
        emit IModuleFactory.FreeDeploymentChanged(true);

        vm.prank(dao);
        moduleFactory.setFreeDeployment(true);

        assertTrue(moduleFactory.freeDeployment());
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMakinaXRegistry} from "src/interfaces/IMakinaXRegistry.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaXRegistry_Unit_Concrete_Test is Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(registry.authority(), address(accessManager));
        assertEq(registry.moduleFactory(), address(moduleFactory));
        assertEq(registry.moduleImplementation(), address(makinaXModuleImplem));
        assertEq(registry.feeCollector(), dao);
        assertEq(registry.flashLoanModule(), address(flashLoanModule));
    }

    function test_SetFeeCollector_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setFeeCollector(address(0));
    }

    function test_SetFeeCollector() public {
        address newFeeCollector = makeAddr("newFeeCollector");

        vm.expectEmit(true, true, false, false, address(registry));
        emit IMakinaXRegistry.FeeCollectorChanged(dao, newFeeCollector);
        vm.prank(dao);
        registry.setFeeCollector(newFeeCollector);

        assertEq(registry.feeCollector(), newFeeCollector);
    }

    function test_SetFlashLoanModule_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setFlashLoanModule(address(0));
    }

    function test_SetFlashLoanModule() public {
        address newFlashLoanModule = makeAddr("newFlashLoanModule");

        vm.expectEmit(true, true, false, false, address(registry));
        emit IMakinaXRegistry.FlashLoanModuleChanged(address(flashLoanModule), newFlashLoanModule);
        vm.prank(dao);
        registry.setFlashLoanModule(newFlashLoanModule);

        assertEq(registry.flashLoanModule(), newFlashLoanModule);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMakinaLiteRegistry} from "src/interfaces/IMakinaLiteRegistry.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaLiteRegistry_Unit_Concrete_Test is Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(registry.authority(), address(accessManager));
        assertEq(registry.feeCollector(), dao);
    }

    function test_SetFeeCollector_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setFeeCollector(address(0));
    }

    function test_SetFeeCollector() public {
        address newFeeCollector = makeAddr("newFeeCollector");

        vm.expectEmit(true, true, false, false, address(registry));
        emit IMakinaLiteRegistry.FeeCollectorChanged(dao, newFeeCollector);
        vm.prank(dao);
        registry.setFeeCollector(newFeeCollector);

        assertEq(registry.feeCollector(), newFeeCollector);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {FlashLoanModule} from "src/flash-loans/FlashLoanModule.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract FlashLoanModule_Unit_Concrete_Test is Unit_Concrete_Test {
    function test_Constructor_RevertWhen_ZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new FlashLoanModule(address(0), address(morpho));

        vm.expectRevert(Errors.ZeroAddress.selector);
        new FlashLoanModule(address(moduleFactory), address(0));
    }

    function test_Getters() public view {
        assertEq(flashLoanModule.moduleFactory(), address(moduleFactory));
        assertEq(flashLoanModule.morpho(), address(morpho));
    }
}

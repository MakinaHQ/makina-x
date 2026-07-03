// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract ManagePositionBatch_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), 3e18, true);

        IWeirollComponent.Instruction[] memory mgmtInstructions = new IWeirollComponent.Instruction[](1);
        mgmtInstructions[0] = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);

        IWeirollComponent.Instruction[] memory acctInstructions = new IWeirollComponent.Instruction[](1);
        acctInstructions[0] = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        tokenB.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaXModule),
            abi.encodeCall(IWeirollComponent.managePositionBatch, (mgmtInstructions, acctInstructions))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.managePositionBatch(mgmtInstructions, acctInstructions);
    }

    function test_RevertWhen_NotOperational() public {
        IWeirollComponent.Instruction[] memory dummyInstructions;

        // module paused
        vm.prank(guardian);
        makinaXModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaXModule.managePositionBatch(dummyInstructions, dummyInstructions);

        // module suspended + paused
        vm.prank(dao);
        makinaXModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.managePositionBatch(dummyInstructions, dummyInstructions);

        // module suspended
        vm.prank(guardian);
        makinaXModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.managePositionBatch(dummyInstructions, dummyInstructions);
    }

    function test_RevertWhen_CallerNotOperator() public {
        IWeirollComponent.Instruction[] memory dummyInstructions;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.managePositionBatch(dummyInstructions, dummyInstructions);
    }

    function test_RevertWhen_MismatchedLengths() public {
        IWeirollComponent.Instruction[] memory mgmtInstructions = new IWeirollComponent.Instruction[](2);
        IWeirollComponent.Instruction[] memory acctInstructions = new IWeirollComponent.Instruction[](1);

        vm.expectRevert(Errors.MismatchedLengths.selector);
        vm.prank(operator);
        makinaXModule.managePositionBatch(mgmtInstructions, acctInstructions);
    }

    function test_ManagePositionBatch() public {
        _test_ManagePositionBatch(false);
    }

    function test_ManagePositionBatch_WhileInFencedMode() public whileInFencedMode {
        _test_ManagePositionBatch(false);
    }

    function test_ManagePositionBatch_WhileInWalledMode() public whileInWalledMode {
        _test_ManagePositionBatch(true);
    }

    ///
    /// Shared test logic
    ///

    function _test_ManagePositionBatch(bool guarded) internal {
        uint256 supplyInputAmount = 3e18;
        uint256 borrowInputAmount = 2e18;

        deal(address(tokenB), address(safe), supplyInputAmount, true);
        deal(address(tokenB), address(borrowModule), borrowInputAmount, true);

        IWeirollComponent.Instruction[] memory mgmtInstructions = new IWeirollComponent.Instruction[](2);
        mgmtInstructions[0] =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), supplyInputAmount);
        mgmtInstructions[1] =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), borrowInputAmount);

        IWeirollComponent.Instruction[] memory acctInstructions = new IWeirollComponent.Instruction[](2);
        acctInstructions[0] =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));
        acctInstructions[1] =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        uint256 expectedSupplyPosValue = supplyInputAmount * PRICE_B_E;
        uint256 expectedBorrowPosValue = borrowInputAmount * PRICE_B_E;

        vm.expectEmit(true, false, false, true, address(makinaXModule));
        emit IWeirollComponent.PositionManaged(true, guarded, SUPPLY_POS_ID, expectedSupplyPosValue);

        vm.expectEmit(true, false, false, true, address(makinaXModule));
        emit IWeirollComponent.PositionManaged(true, guarded, BORROW_POS_ID, expectedBorrowPosValue);

        uint256[] memory values;
        int256[] memory changes;

        vm.prank(operator);
        (values, changes) = makinaXModule.managePositionBatch(mgmtInstructions, acctInstructions);

        assertEq(values.length, 2);
        assertEq(changes.length, 2);

        assertEq(tokenB.balanceOf(address(safe)), borrowInputAmount);
        assertEq(supplyModule.collateralOf(address(safe)), supplyInputAmount);
        assertEq(borrowModule.debtOf(address(safe)), borrowInputAmount);

        assertEq(values[0], expectedSupplyPosValue);
        assertEq(uint256(changes[0]), values[0]);
        assertEq(values[1], expectedBorrowPosValue);
        assertEq(uint256(changes[1]), values[1]);
    }
}

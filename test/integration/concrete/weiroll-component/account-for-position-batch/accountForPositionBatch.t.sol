// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract AccountForPositionBatch_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function setUp() public override {
        WeirollComponent_Integration_Concrete_Test.setUp();

        uint256 vaultInputAmount = 2e18;

        deal(address(tokenB), address(safe), vaultInputAmount, true);

        // create vault position
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), vaultInputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        vm.prank(operator);
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 borrowInputAmount = 1e18;
        deal(address(tokenB), address(borrowModule), borrowInputAmount, true);
        IWeirollComponent.Instruction memory borrowMgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), borrowInputAmount);
        IWeirollComponent.Instruction memory borrowAcctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        tokenB.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaXModule),
            abi.encodeCall(
                IWeirollComponent.accountForPositionBatch, (new IWeirollComponent.Instruction[](0), new uint256[](0))
            )
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.managePosition(borrowMgmtInstruction, borrowAcctInstruction);
    }

    function test_RevertWhen_NotOperational() public {
        IWeirollComponent.Instruction[] memory instructions;

        // module paused
        vm.prank(guardian);
        makinaXModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaXModule.accountForPositionBatch(instructions, new uint256[](0));

        // module suspended + paused
        vm.prank(dao);
        makinaXModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.accountForPositionBatch(instructions, new uint256[](0));

        // module suspended
        vm.prank(guardian);
        makinaXModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.accountForPositionBatch(instructions, new uint256[](0));
    }

    function test_AccountForPositionBatch() public {
        // create supply position
        uint256 supplyInputAmount = 2e18;
        deal(address(tokenB), address(safe), supplyInputAmount, true);
        IWeirollComponent.Instruction memory supplyMgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), supplyInputAmount);
        IWeirollComponent.Instruction memory supplyAcctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));
        vm.prank(operator);
        makinaXModule.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        // create borrow position
        uint256 borrowInputAmount = 1e18;
        deal(address(tokenB), address(borrowModule), borrowInputAmount, true);
        IWeirollComponent.Instruction memory borrowMgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), borrowInputAmount);
        IWeirollComponent.Instruction memory borrowAcctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));
        vm.prank(operator);
        makinaXModule.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // account for supply and borrow positions in a batch
        IWeirollComponent.Instruction[] memory accountingInstructions = new IWeirollComponent.Instruction[](2);
        accountingInstructions[0] = supplyAcctInstruction;
        accountingInstructions[1] = borrowAcctInstruction;
        vm.prank(operator);
        uint256[] memory values = makinaXModule.accountForPositionBatch(accountingInstructions, new uint256[](0));

        assertEq(values.length, 2);

        assertEq(values[0], supplyInputAmount * PRICE_B_E);
        assertEq(values[1], borrowInputAmount * PRICE_B_E);

        vm.prank(operator);
        makinaXModule.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }
}

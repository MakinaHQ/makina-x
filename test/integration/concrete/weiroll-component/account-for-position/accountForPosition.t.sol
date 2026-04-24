// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract AccountForPosition_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
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
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 borrowInputAmount = 1e18;
        deal(address(tokenA), address(borrowModule), borrowInputAmount, true);
        IWeirollComponent.Instruction memory borrowMgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), borrowInputAmount);
        IWeirollComponent.Instruction memory borrowAcctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        tokenA.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaLiteModule),
            abi.encodeCall(IWeirollComponent.accountForPosition, (borrowAcctInstruction))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.managePosition(borrowMgmtInstruction, borrowAcctInstruction);
    }

    function test_RevertWhen_NotOperational() public {
        IWeirollComponent.Instruction memory instruction;

        // module paused
        vm.prank(guardian);
        makinaLiteModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaLiteModule.accountForPosition(instruction);

        // module suspended + paused
        vm.prank(dao);
        makinaLiteModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.accountForPosition(instruction);

        // module suspended
        vm.prank(guardian);
        makinaLiteModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_RevertWhen_CallerNotOperator() public {
        IWeirollComponent.Instruction memory instruction;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_RevertWhen_ProvidedInstructionNonAccountingType() public {
        IWeirollComponent.Instruction memory instruction;
        _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 0);

        vm.expectRevert(Errors.InvalidInstructionType.selector);
        vm.prank(operator);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_RevertWhen_ProvidedProofInvalid() public {
        vm.startPrank(operator);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(tokenA), 0);
        IWeirollComponent.Instruction memory instruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong posId
        instruction = _build4626AccountingInstruction(address(safe), SUPPLY_POS_ID, address(vault));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong isDebt
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.isDebt = true;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong groupId
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.groupId = 1;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong affected tokens list
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong commands
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.commands[2] = instruction.commands[1];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong state
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.state[2] = instruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        // use wrong bitmap
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        instruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.accountForPosition(instruction);

        vm.stopPrank();

        // use new root
        vm.prank(address(safe));
        makinaLiteModule.setAllowedInstrRoot(keccak256(abi.encodePacked("newRoot")));
        instruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_RevertGiven_InstructionFails() public {
        vault.setAccountingDisabled(true);

        IWeirollComponent.Instruction memory instruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_RevertGiven_AccountingOutputStateInvalid() public {
        IWeirollComponent.Instruction memory instruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        // replace end flag with null value in accounting output state
        delete instruction.state[1];
        vm.expectRevert(Errors.InvalidAccounting.selector);
        vm.prank(operator);
        makinaLiteModule.accountForPosition(instruction);
    }

    function test_AccountForPosition_4626() public {
        uint256 safeBal = vault.balanceOf(address(safe));

        uint256 yield = 1e18;
        deal(address(tokenB), address(vault), tokenB.balanceOf(address(vault)) + yield, true);

        uint256 expectedValue = makinaLiteModule.getReferencePrice(address(tokenB))
            * vault.previewRedeem(vault.balanceOf(address(safe))) / 1e18;

        IWeirollComponent.Instruction memory instruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        vm.prank(operator);
        uint256 value = makinaLiteModule.accountForPosition(instruction);

        assertEq(vault.balanceOf(address(safe)), safeBal);
        assertEq(value, expectedValue);
    }
}

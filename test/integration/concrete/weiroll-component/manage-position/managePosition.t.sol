// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract ManagePosition_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), 3e18, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        tokenB.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaLiteModule),
            abi.encodeCall(IWeirollComponent.managePosition, (mgmtInstruction, acctInstruction))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_NotOperational() public {
        IWeirollComponent.Instruction memory dummyInstruction;

        // module paused
        vm.prank(guardian);
        makinaLiteModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(dummyInstruction, dummyInstruction);

        // module suspended + paused
        vm.prank(dao);
        makinaLiteModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(dummyInstruction, dummyInstruction);

        // module suspended
        vm.prank(guardian);
        makinaLiteModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(dummyInstruction, dummyInstruction);
    }

    function test_RevertWhen_CallerNotOperator() public {
        IWeirollComponent.Instruction memory dummyInstruction;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaLiteModule.managePosition(dummyInstruction, dummyInstruction);
    }

    function test_RevertWhen_PositionIdZero() public {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), 0, address(vault), 0);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), 0, address(vault));
        vm.prank(operator);
        vm.expectRevert(Errors.ZeroPositionId.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedFirstInstructionNonManagementType() public {
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.prank(operator);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        makinaLiteModule.managePosition(acctInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedFirstInstructionProofInvalid() public {
        uint256 inputAmount = 3e18;

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(tokenB), 0);
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault2), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong posId
        mgmtInstruction = _build4626DepositInstruction(address(safe), SUPPLY_POS_ID, address(vault), inputAmount);
        acctInstruction.positionId = SUPPLY_POS_ID;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong isDebt
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.isDebt = true;
        acctInstruction.isDebt = true;
        acctInstruction.positionId = VAULT_POS_ID;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong groupId
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.groupId = 1;
        acctInstruction.isDebt = false;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong affected tokens list
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong position tokens list
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.positionTokens = new address[](1);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong commands
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.commands[1] = mgmtInstruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong state
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.state[2] = mgmtInstruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong bitmap
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use new root
        vm.prank(address(safe));
        makinaLiteModule.setAllowedInstrRoot(keccak256(abi.encodePacked("newRoot")));
        mgmtInstruction = _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedInstructionsMismatch() public {
        vm.startPrank(operator);

        // instructions have different positionId
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), SUPPLY_POS_ID, address(vault));
        vm.expectRevert(Errors.InstructionsMismatch.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // instructions have different isDebt flags
        acctInstruction.positionId = VAULT_POS_ID;
        acctInstruction.isDebt = true;
        vm.expectRevert(Errors.InstructionsMismatch.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedSecondInstructionNonAccountingType() public {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        vm.prank(operator);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        makinaLiteModule.managePosition(mgmtInstruction, mgmtInstruction);
    }

    function test_RevertWhen_ProvidedSecondInstructionProofInvalid() public {
        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(tokenB), 0);
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong affected tokens list
        acctInstruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        acctInstruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong position tokens list
        acctInstruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        acctInstruction.positionTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong commands
        acctInstruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        delete acctInstruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong state
        acctInstruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        delete acctInstruction.state[2];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // use wrong bitmap
        acctInstruction = _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        acctInstruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_ProvidedSecondInstructionFails() public {
        vault.setAccountingDisabled(true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_AccountingOutputStateInvalid() public {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        // replace end flag with null value in accounting output state
        delete acctInstruction.state[1];
        vm.prank(operator);
        vm.expectRevert(Errors.InvalidAccounting.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_AffectedTokensInvalid() public {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        vm.prank(address(safe));
        makinaLiteModule.clearFeedRoute(address(tokenB));

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenB)));
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_ProvidedFirstInstructionFails() public {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 3e18);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_ManagePosition_4626_WithValuation_ReferenceCurrency() public {
        _test_ManagePosition_4626_WithValuation(PRICE_B_E, false);
    }

    function test_ManagePosition_4626_WithValuation_PositionCurrency() public withAccountingCurrency(address(tokenB)) {
        _test_ManagePosition_4626_WithValuation(1, false);
    }

    function test_ManagePosition_4626_WithValuation_OtherCurrency() public withAccountingCurrency(address(tokenA)) {
        _test_ManagePosition_4626_WithValuation(PRICE_B_A, false);
    }

    function test_ManagePosition_SupplyModule_WithValuation_ReferenceCurrency() public {
        _test_ManagePosition_SupplyModule_WithValuation(PRICE_B_E, false);
    }

    function test_ManagePosition_SupplyModule_WithValuation_PositionCurrency()
        public
        withAccountingCurrency(address(tokenB))
    {
        _test_ManagePosition_SupplyModule_WithValuation(1, false);
    }

    function test_ManagePosition_SupplyModule_WithValuation_OtherCurrency()
        public
        withAccountingCurrency(address(tokenA))
    {
        _test_ManagePosition_SupplyModule_WithValuation(PRICE_B_A, false);
    }

    function test_ManagePosition_BorrowModule_WithValuation_ReferenceCurrency() public {
        _test_ManagePosition_BorrowModule_WithValuation(PRICE_B_E, false);
    }

    function test_ManagePosition_BorrowModule_WithValuation_PositionCurrency()
        public
        withAccountingCurrency(address(tokenB))
    {
        _test_ManagePosition_BorrowModule_WithValuation(1, false);
    }

    function test_ManagePosition_BorrowModule_WithValuation_OtherCurrency()
        public
        withAccountingCurrency(address(tokenA))
    {
        _test_ManagePosition_BorrowModule_WithValuation(PRICE_B_A, false);
    }

    function test_ManagePosition_4626_WithoutValuation() public {
        uint256 inputAmount = 3e18;
        uint256 expectedShares = vault.previewDeposit(inputAmount);

        deal(address(tokenB), address(safe), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);

        // empty instruction
        IWeirollComponent.Instruction memory acctInstruction;

        // create position
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(false, false, VAULT_POS_ID, 0);
        vm.prank(operator);
        (uint256 value, int256 change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, 0);
        assertEq(change, 0);

        expectedShares += vault.previewDeposit(inputAmount);

        // increase position
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(false, false, VAULT_POS_ID, 0);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 0);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, 0);
        assertEq(change, 0);

        uint256 sharesToRedeem = vault.balanceOf(address(safe)) / 2;
        mgmtInstruction = _build4626RedeemInstruction(address(safe), VAULT_POS_ID, address(vault), sharesToRedeem);

        expectedShares -= sharesToRedeem;

        // decrease position
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(false, false, VAULT_POS_ID, 0);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, 0);
        assertEq(change, 0);

        expectedShares = 0;

        // close position
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(false, false, VAULT_POS_ID, 0);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 2 * inputAmount);
        assertEq(vault.balanceOf(address(safe)), 0);
        assertEq(value, 0);
        assertEq(change, 0);
    }

    // base tokens are received but non-debt position increases
    function test_FavorableMove_PositionIncrease_NonDebt() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but debt position decreases
    function test_FavorableMove_PositionDecrease_Debt() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try increase position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // no base tokens flow nor non-debt position change
    function test_NeutralMove_NonDebt() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), 0);

        // try neutral move
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // no base tokens flow nor debt position change
    function test_NeutralMove_Debt() public {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), 0);

        // try neutral move
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are spent but non-debt position decreases
    function test_RevertGiven_InvalidPositionChangeDirection_NonDebt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        // try increase position
        vm.prank(operator);
        vm.expectRevert(Errors.InvalidPositionChangeDirection.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are spent but debt position increases
    function test_RevertGiven_InvalidPositionChangeDirection_Debt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try repay debt
        vm.prank(operator);
        vm.expectRevert(Errors.InvalidPositionChangeDirection.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position does not increase as much as expected
    function test_RevertGiven_ValueLossTooHigh_PositionIncrease_NonDebt_WhileInLockDownMode()
        public
        whileInLockdownMode
    {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        // decrease borrowModule rate
        supplyModule.setRateBps(10_000 - DEFAULT_MAX_POS_INCREASE_LOSS_BPS - 1);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // try create position
        vm.prank(operator);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position increases more than expected
    function test_RevertGiven_ValueLossTooHigh_PositionIncrease_Debt_WhileInLockDownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), inputAmount, true);

        // increase borrowModule rate
        borrowModule.setRateBps(10_000 + DEFAULT_MAX_POS_INCREASE_LOSS_BPS + 1);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // try create position
        vm.prank(operator);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position decreases more than expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_NonDebt_WhileInLockDownMode()
        public
        whileInLockdownMode
    {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // increase supplyModule rate
        supplyModule.setRateBps(10_000 + DEFAULT_MAX_POS_DECREASE_LOSS_BPS + 1);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // try decrease position
        vm.prank(operator);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        supplyModule.setRateBps(10_000 + DEFAULT_MAX_POS_INCREASE_LOSS_BPS + 1);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // debt position does not decrease as much as expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_Debt_WhileInLockDownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // decrease borrowModule rate
        borrowModule.setRateBps(10_000 - DEFAULT_MAX_POS_DECREASE_LOSS_BPS - 1);

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        vm.prank(operator);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        borrowModule.setRateBps(10_000 - DEFAULT_MAX_POS_INCREASE_LOSS_BPS - 1);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_NoAccountingInstructionProvided_WhileInLockDownMode() public whileInLockdownMode {
        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 0);

        IWeirollComponent.Instruction memory acctInstruction;

        vm.expectRevert(Errors.AccountingMandatory.selector);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_ManagePosition_4626_WithValuation_ReferenceCurrency_WhileInLockdownMode() public whileInLockdownMode {
        _test_ManagePosition_4626_WithValuation(PRICE_B_E, true);
    }

    function test_ManagePosition_4626_WithValuation_PositionCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenB))
        whileInLockdownMode
    {
        _test_ManagePosition_4626_WithValuation(1, true);
    }

    function test_ManagePosition_4626_WithValuation_OtherCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenA))
        whileInLockdownMode
    {
        _test_ManagePosition_4626_WithValuation(PRICE_B_A, true);
    }

    function test_ManagePosition_SupplyModule_WithValuation_ReferenceCurrency_WhileInLockdownMode()
        public
        whileInLockdownMode
        whileInLockdownMode
    {
        _test_ManagePosition_SupplyModule_WithValuation(PRICE_B_E, true);
    }

    function test_ManagePosition_SupplyModule_WithValuation_PositionCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenB))
        whileInLockdownMode
    {
        _test_ManagePosition_SupplyModule_WithValuation(1, true);
    }

    function test_ManagePosition_SupplyModule_WithValuation_OtherCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenA))
        whileInLockdownMode
    {
        _test_ManagePosition_SupplyModule_WithValuation(PRICE_B_A, true);
    }

    function test_ManagePosition_BorrowModule_WithValuation_ReferenceCurrency_WhileInLockdownMode()
        public
        whileInLockdownMode
    {
        _test_ManagePosition_BorrowModule_WithValuation(PRICE_B_E, true);
    }

    function test_ManagePosition_BorrowModule_WithValuation_PositionCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenB))
        whileInLockdownMode
    {
        _test_ManagePosition_BorrowModule_WithValuation(1, true);
    }

    function test_ManagePosition_BorrowModule_WithValuation_OtherCurrency_WhileInLockdownMode()
        public
        withAccountingCurrency(address(tokenA))
        whileInLockdownMode
    {
        _test_ManagePosition_BorrowModule_WithValuation(PRICE_B_A, true);
    }

    // base tokens are received but non-debt position increases
    function test_FavorableMove_PositionIncrease_NonDebt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but debt position decreases
    function test_FavorableMove_PositionDecrease_Debt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try increase position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // no base tokens flow nor non-debt position change
    function test_NeutralMove_NonDebt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), 0);

        // try neutral move
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    // no base tokens flow nor debt position change
    function test_NeutralMove_Debt_WhileInLockdownMode() public whileInLockdownMode {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), 0);

        // try neutral move
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    ///
    /// Shared test logic
    ///

    function _test_ManagePosition_4626_WithValuation(uint256 priceTokenBInAccountingCurrency, bool lockdownMode)
        internal
    {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));

        // create position
        uint256 expectedShares = vault.previewDeposit(inputAmount);
        uint256 expectedValue = inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, VAULT_POS_ID, expectedValue);
        vm.prank(operator);
        (uint256 value, int256 change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, expectedValue);
        assertEq(uint256(change), value);

        // increase position
        expectedShares += vault.previewDeposit(inputAmount);
        expectedValue += inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, VAULT_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 0);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, expectedValue);
        assertEq(uint256(change), inputAmount * priceTokenBInAccountingCurrency);

        uint256 sharesToRedeem = vault.balanceOf(address(safe)) / 2;
        mgmtInstruction = _build4626RedeemInstruction(address(safe), VAULT_POS_ID, address(vault), sharesToRedeem);

        // decrease position
        expectedShares -= sharesToRedeem;
        expectedValue -= inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, VAULT_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));

        // close position
        expectedShares = 0;
        expectedValue = 0;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, VAULT_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 2 * inputAmount);
        assertEq(vault.balanceOf(address(safe)), expectedShares);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));
    }

    function _test_ManagePosition_SupplyModule_WithValuation(uint256 priceTokenBInAccountingCurrency, bool lockdownMode)
        internal
    {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(safe), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule));

        // create position
        uint256 expectedValue = inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, SUPPLY_POS_ID, expectedValue);
        vm.prank(operator);
        (uint256 value, int256 change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(supplyModule.collateralOf(address(safe)), inputAmount);
        assertEq(value, expectedValue);
        assertEq(uint256(change), value);

        // increase position
        expectedValue += inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, SUPPLY_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 0);
        assertEq(supplyModule.collateralOf(address(safe)), 2 * inputAmount);
        assertEq(value, expectedValue);
        assertEq(uint256(change), inputAmount * priceTokenBInAccountingCurrency);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // decrease position
        expectedValue -= inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, SUPPLY_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(supplyModule.collateralOf(address(safe)), inputAmount);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));

        // close position
        expectedValue = 0;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, SUPPLY_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 2 * inputAmount);
        assertEq(supplyModule.collateralOf(address(safe)), 0);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));
    }

    function _test_ManagePosition_BorrowModule_WithValuation(uint256 priceTokenBInAccountingCurrency, bool lockdownMode)
        internal
    {
        uint256 inputAmount = 3e18;

        deal(address(tokenB), address(borrowModule), 2 * inputAmount, true);

        IWeirollComponent.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule));

        // create position
        uint256 expectedValue = inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, BORROW_POS_ID, expectedValue);
        vm.prank(operator);
        (uint256 value, int256 change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(borrowModule.debtOf(address(safe)), inputAmount);
        assertEq(value, expectedValue);
        assertEq(uint256(change), value);

        // increase position
        expectedValue += inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, BORROW_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 2 * inputAmount);
        assertEq(borrowModule.debtOf(address(safe)), 2 * inputAmount);
        assertEq(value, expectedValue);
        assertEq(uint256(change), inputAmount * priceTokenBInAccountingCurrency);

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // decrease position
        expectedValue -= inputAmount * priceTokenBInAccountingCurrency;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, BORROW_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), inputAmount);
        assertEq(borrowModule.debtOf(address(safe)), inputAmount);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));

        // close position
        expectedValue = 0;
        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit IWeirollComponent.PositionManaged(true, lockdownMode, BORROW_POS_ID, expectedValue);
        vm.prank(operator);
        (value, change) = makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(tokenB.balanceOf(address(safe)), 0);
        assertEq(borrowModule.debtOf(address(safe)), 0);
        assertEq(value, expectedValue);
        assertEq(change, -1 * int256(inputAmount * priceTokenBInAccountingCurrency));
    }
}

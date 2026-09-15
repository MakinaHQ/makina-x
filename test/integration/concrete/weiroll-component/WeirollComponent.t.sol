// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {InstructionHelper} from "test/utils/InstructionHelper.sol";
import {RootfileHelper} from "test/utils/RootfileHelper.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract WeirollComponent_Integration_Concrete_Test is
    Integration_Concrete_Test,
    InstructionHelper,
    RootfileHelper
{
    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        _addInstructionLeaves();

        vm.prank(address(safe));
        makinaXModule.setAllowedInstrRoot(_rootfileRoot());
    }

    function _addInstructionLeaves() internal {
        _addLeaf(_build4626DepositInstruction(address(safe), VAULT_POS_ID, address(vault), 0));
        _addLeaf(_build4626RedeemInstruction(address(safe), VAULT_POS_ID, address(vault), 0));
        _addLeaf(_build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault)));
        _addLeaf(_buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), 0));
        _addLeaf(_buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), 0));
        _addLeaf(_buildMockSupplyModuleAccountingInstruction(address(safe), SUPPLY_POS_ID, address(supplyModule)));
        _addLeaf(_buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), 0));
        _addLeaf(_buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), 0));
        _addLeaf(_buildMockBorrowModuleAccountingInstruction(address(safe), BORROW_POS_ID, address(borrowModule)));
        _addLeaf(_buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), 0));
        // the flash loan request is a free state value: token, amount and nested instruction are not in the leaf
        IWeirollComponent.Instruction memory emptyInstruction;
        _addLeaf(
            _buildFlashLoanModuleDummyLoopInstruction(
                LOOP_POS_ID, address(flashLoanModule), address(makinaXModule), address(0), 0, emptyInstruction
            )
        );
        _addLeaf(_buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID));
        _addLeaf(_buildManageFlashLoanDummyInstruction(LOOP_POS_ID));
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {VM} from "@enso-weiroll/VM.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract ManageFlashLoan_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        MockERC20 token = new MockERC20("Token", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(morpho), 2 * flashLoanAmount, true);

        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        IWeirollComponent.Instruction memory mgmtInstruction = _buildFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID,
            address(flashLoanModule),
            address(makinaLiteModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        morpho.setReentrancyMode(true);

        vm.expectRevert(
            abi.encodeWithSelector(VM.ExecutionFailed.selector, 0, address(flashLoanModule), string("Unknown"))
        );
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_CallerNotFlashLoanModule() public {
        IWeirollComponent.Instruction memory dummyInstruction;
        vm.expectRevert(Errors.NotFlashLoanModule.selector);
        makinaLiteModule.manageFlashLoan(dummyInstruction, address(0), 0);
    }

    function test_RevertWhen_DirectCall() public {
        IWeirollComponent.Instruction memory dummyInstruction;
        vm.expectRevert(Errors.DirectManageFlashLoanCall.selector);
        vm.prank(address(flashLoanModule));
        makinaLiteModule.manageFlashLoan(dummyInstruction, address(0), 0);
    }

    function test_RevertWhen_ProvidedInstructionNonFlashLoanManagementType() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(morpho), flashLoanAmount, true);

        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.instructionType = IWeirollComponent.InstructionType.MANAGEMENT;
        IWeirollComponent.Instruction memory mgmtInstruction = _buildFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID,
            address(flashLoanModule),
            address(makinaLiteModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        vm.expectRevert(
            abi.encodeWithSelector(VM.ExecutionFailed.selector, 0, address(flashLoanModule), string("Unknown"))
        );
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedInstructionsMismatch() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(morpho), flashLoanAmount, true);

        bytes memory errorData =
            abi.encodeWithSelector(VM.ExecutionFailed.selector, 0, address(flashLoanModule), string("Unknown"));

        // instructions have different positionId
        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID + 1);
        IWeirollComponent.Instruction memory mgmtInstruction = _buildFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID,
            address(flashLoanModule),
            address(makinaLiteModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);
        vm.expectRevert(errorData);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        // instructions have different isDebt flag
        flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;
        vm.expectRevert(errorData);
        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_InstructionsAreDebt() public {
        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;

        // overwrite IS_MANAGED_POSITION_DEBT_SLOT and MANAGED_POSITION_ID_SLOT transient slots
        TransientOverwrite transientOverwrite = new TransientOverwrite();
        bytes32 IS_MANAGED_POSITION_DEBT_SLOT = 0x4e4b4e291d20f6f03003921c4d26de1006021d95c6c1641168790b4e4b3b7200;
        bytes32 MANAGED_POSITION_ID_SLOT = 0xfbb6b868544e1f69cf175881d715d83b048bd3f24bc7e327034891f3b849d600;
        bytes memory originalCode = address(makinaLiteModule).code;
        vm.etch(address(makinaLiteModule), address(transientOverwrite).code);
        TransientOverwrite(address(makinaLiteModule)).set(IS_MANAGED_POSITION_DEBT_SLOT, bytes32(uint256(1)));
        TransientOverwrite(address(makinaLiteModule)).set(MANAGED_POSITION_ID_SLOT, bytes32(LOOP_POS_ID));
        vm.etch(address(makinaLiteModule), originalCode);

        vm.expectRevert(Errors.InvalidDebtFlag.selector);
        vm.prank(address(flashLoanModule));
        makinaLiteModule.manageFlashLoan(flMgmtInstruction, address(0), 0);
    }

    function test_ManageFlashLoan() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 3e18;
        deal(address(token), address(morpho), flashLoanAmount, true);

        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        IWeirollComponent.Instruction memory mgmtInstruction = _buildFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID,
            address(flashLoanModule),
            address(makinaLiteModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        vm.prank(operator);
        makinaLiteModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(token.balanceOf(address(morpho)), flashLoanAmount);
        assertEq(token.balanceOf(address(makinaLiteModule)), 0);
        assertEq(token.balanceOf(address(safe)), 0);
    }
}

contract TransientOverwrite {
    function set(bytes32 slot, bytes32 value) external {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Vm} from "forge-std/Vm.sol";

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
            address(makinaXModule),
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
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_CallerNotFlashLoanModule() public {
        IWeirollComponent.Instruction memory dummyInstruction;
        vm.expectRevert(Errors.NotFlashLoanModule.selector);
        makinaXModule.manageFlashLoan(dummyInstruction, address(0), 0);
    }

    function test_RevertWhen_DirectCall() public {
        IWeirollComponent.Instruction memory dummyInstruction;
        vm.expectRevert(Errors.DirectManageFlashLoanCall.selector);
        vm.prank(address(flashLoanModule));
        makinaXModule.manageFlashLoan(dummyInstruction, address(0), 0);
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
            address(makinaXModule),
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
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);
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
            address(makinaXModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);
        vm.expectRevert(errorData);
        vm.prank(operator);
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);

        // instructions have different isDebt flag
        flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;
        vm.expectRevert(errorData);
        vm.prank(operator);
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_InstructionsAreDebt() public {
        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;

        // overwrite IS_MANAGED_POSITION_DEBT_SLOT and MANAGED_POSITION_ID_SLOT transient slots, then call
        // manageFlashLoan within the same transaction
        bytes32 IS_MANAGED_POSITION_DEBT_SLOT = 0x4e4b4e291d20f6f03003921c4d26de1006021d95c6c1641168790b4e4b3b7200;
        bytes32 MANAGED_POSITION_ID_SLOT = 0xfbb6b868544e1f69cf175881d715d83b048bd3f24bc7e327034891f3b849d600;
        TransientContextCaller transientContextCaller = new TransientContextCaller();

        vm.expectRevert(Errors.InvalidDebtFlag.selector);
        transientContextCaller.setTransientAndCall(
            address(makinaXModule),
            [IS_MANAGED_POSITION_DEBT_SLOT, MANAGED_POSITION_ID_SLOT],
            [bytes32(uint256(1)), bytes32(LOOP_POS_ID)],
            address(flashLoanModule),
            abi.encodeCall(IWeirollComponent.manageFlashLoan, (flMgmtInstruction, address(0), 0))
        );
    }

    function test_ManageFlashLoan() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 3e18;
        deal(address(token), address(morpho), flashLoanAmount, true);

        IWeirollComponent.Instruction memory flMgmtInstruction = _buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        IWeirollComponent.Instruction memory mgmtInstruction = _buildFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID,
            address(flashLoanModule),
            address(makinaXModule),
            address(token),
            flashLoanAmount,
            flMgmtInstruction
        );
        IWeirollComponent.Instruction memory acctInstruction =
            _buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        vm.prank(operator);
        makinaXModule.managePosition(mgmtInstruction, acctInstruction);

        assertEq(token.balanceOf(address(morpho)), flashLoanAmount);
        assertEq(token.balanceOf(address(makinaXModule)), 0);
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

/// @dev Writes transient storage slots of `target` and calls it within the same transaction,
/// so the transient state is still set when the call executes under isolated test mode.
contract TransientContextCaller {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setTransientAndCall(
        address target,
        bytes32[2] memory slots,
        bytes32[2] memory values,
        address caller,
        bytes memory data
    ) external {
        bytes memory originalCode = target.code;
        vm.etch(target, type(TransientOverwrite).runtimeCode);
        TransientOverwrite(target).set(slots[0], values[0]);
        TransientOverwrite(target).set(slots[1], values[1]);
        vm.etch(target, originalCode);

        vm.prank(caller);
        (bool success, bytes memory returnData) = target.call(data);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}

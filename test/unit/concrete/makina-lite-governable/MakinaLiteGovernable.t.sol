// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaLiteGovernable} from "src/interfaces/IMakinaLiteGovernable.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaLiteGovernable_Unit_Concrete_Test is Unit_Concrete_Test {
    IMakinaLiteGovernable internal makinaGovernable;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        makinaGovernable = IMakinaLiteGovernable(address(makinaLiteModule));
    }

    function test_Getters() public view {
        assertEq(makinaGovernable.safe(), address(safe));
        assertEq(makinaGovernable.provider(), dao);
        assertFalse(makinaGovernable.lockdownMode());
    }

    function test_SetProvider_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.setProvider(address(0));
    }

    function test_SetProvider() public {
        address newProvider = makeAddr("newProvider");

        vm.expectEmit(true, true, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.ProviderChanged(dao, newProvider);
        vm.prank(dao);
        makinaGovernable.setProvider(newProvider);

        assertEq(makinaGovernable.provider(), newProvider);
    }

    function test_AddOperator_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.addOperator(address(0));
    }

    function test_AddOperator_RevertGiven_AlreadyOperator() public {
        address newOperator = makeAddr("newOperator");

        vm.prank(address(safe));
        makinaGovernable.addOperator(newOperator);

        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyOperator.selector));
        vm.prank(address(safe));
        makinaGovernable.addOperator(newOperator);
    }

    function test_AddOperator() public {
        address newOperator = makeAddr("newOperator");

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.OperatorAdded(newOperator);
        vm.prank(address(safe));
        makinaGovernable.addOperator(newOperator);

        assertTrue(makinaGovernable.isOperator(newOperator));
    }

    function test_RemoveOperator_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.removeOperator(address(0));
    }

    function test_RemoveOperator_RevertGiven_NotOperator() public {
        address operator = makeAddr("operator");

        vm.expectRevert(abi.encodeWithSelector(Errors.NotOperator.selector));
        vm.prank(address(safe));
        makinaGovernable.removeOperator(operator);
    }

    function test_RemoveOperator() public {
        address operator = makeAddr("operator");

        vm.prank(address(safe));
        makinaGovernable.addOperator(operator);

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.OperatorRemoved(operator);
        vm.prank(address(safe));
        makinaGovernable.removeOperator(operator);

        assertFalse(makinaGovernable.isOperator(operator));
    }

    function test_AddGuardian_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.addGuardian(address(0));
    }

    function test_AddGuardian_RevertGiven_AlreadyGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        vm.prank(address(safe));
        makinaGovernable.addGuardian(newGuardian);

        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyGuardian.selector));
        vm.prank(address(safe));
        makinaGovernable.addGuardian(newGuardian);
    }

    function test_AddGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.GuardianAdded(newGuardian);
        vm.prank(address(safe));
        makinaGovernable.addGuardian(newGuardian);

        assertTrue(makinaGovernable.isGuardian(newGuardian));
    }

    function test_RemoveGuardian_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.removeGuardian(address(0));
    }

    function test_RemoveGuardian_RevertGiven_ProtectedGuardian() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ProtectedGuardian.selector));
        vm.prank(address(safe));
        makinaGovernable.removeGuardian(address(safe));
    }

    function test_RemoveGuardian_RevertGiven_NotGuardian() public {
        address guardian = makeAddr("guardian");

        vm.expectRevert(abi.encodeWithSelector(Errors.NotGuardian.selector));
        vm.prank(address(safe));
        makinaGovernable.removeGuardian(guardian);
    }

    function test_RemoveGuardian() public {
        address guardian = makeAddr("guardian");

        vm.prank(address(safe));
        makinaGovernable.addGuardian(guardian);

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.GuardianRemoved(guardian);
        vm.prank(address(safe));
        makinaGovernable.removeGuardian(guardian);

        assertFalse(makinaGovernable.isGuardian(guardian));
    }

    function test_SetLockdownMode_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.setLockdownMode(true);
    }

    function test_SetLockdownMode() public {
        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.LockdownModeChanged(true);
        vm.prank(address(safe));
        makinaGovernable.setLockdownMode(true);

        assertTrue(makinaGovernable.lockdownMode());

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.LockdownModeChanged(false);
        vm.prank(address(safe));
        makinaGovernable.setLockdownMode(false);

        assertFalse(makinaGovernable.lockdownMode());
    }

    function test_Suspend_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.suspend();
    }

    function test_Suspend() public {
        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.Suspended();
        vm.prank(dao);
        makinaGovernable.suspend();

        assertTrue(makinaGovernable.suspendedByProvider());

        // can be repeatedly suspended without reverting
        vm.prank(dao);
        makinaGovernable.suspend();

        assertTrue(makinaGovernable.suspendedByProvider());
    }

    function test_Unsuspend_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.unsuspend();
    }

    function test_Unsuspend() public {
        vm.prank(dao);
        makinaGovernable.suspend();

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.Unsuspended();
        vm.prank(dao);
        makinaGovernable.unsuspend();

        assertFalse(makinaGovernable.suspendedByProvider());

        vm.prank(dao);
        makinaGovernable.unsuspend();

        assertFalse(makinaGovernable.suspendedByProvider());
    }

    function test_Pause_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.pause();
    }

    function test_Pause() public {
        address guardian = makeAddr("guardian");

        vm.prank(address(safe));
        makinaGovernable.addGuardian(guardian);

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.Paused(guardian);
        vm.prank(guardian);
        makinaGovernable.pause();

        assertTrue(makinaGovernable.paused());

        // can be repeatedly paused without reverting
        vm.prank(guardian);
        makinaGovernable.pause();

        assertTrue(makinaGovernable.paused());
    }

    function test_Unpause_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector));
        makinaGovernable.unpause();
    }

    function test_Unpause() public {
        address guardian = makeAddr("guardian");

        vm.prank(address(safe));
        makinaGovernable.addGuardian(guardian);

        vm.prank(guardian);
        makinaGovernable.pause();

        vm.expectEmit(true, false, false, false, address(makinaGovernable));
        emit IMakinaLiteGovernable.Unpaused(guardian);
        vm.prank(guardian);
        makinaGovernable.unpause();

        assertFalse(makinaGovernable.paused());

        vm.prank(guardian);
        makinaGovernable.unpause();

        assertFalse(makinaGovernable.paused());
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract WeirollComponent_Unit_Concrete_Test is Unit_Concrete_Test {
    IWeirollComponent internal weirollComponent;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        weirollComponent = IWeirollComponent(address(makinaXModule));
    }
}

contract Getters_Setters_WeirollComponent_Unit_Concrete_Test is WeirollComponent_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(weirollComponent.weirollVm(), weirollVM);
        assertEq(weirollComponent.allowedInstrRoot(), bytes32(0));
        assertEq(weirollComponent.maxPositionIncreaseLossBps(), DEFAULT_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(weirollComponent.maxPositionDecreaseLossBps(), DEFAULT_MAX_POS_DECREASE_LOSS_BPS);
    }

    function test_SetAllowedInstrRoot_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        weirollComponent.setAllowedInstrRoot(bytes32(0));
    }

    function test_SetAllowedInstrRoot() public {
        bytes32 newAllowedInstrRoot = keccak256("newAllowedInstrRoot");

        vm.expectEmit(true, true, false, false, address(weirollComponent));
        emit IWeirollComponent.AllowedInstrRootChanged(bytes32(0), newAllowedInstrRoot);
        vm.prank(address(safe));
        weirollComponent.setAllowedInstrRoot(newAllowedInstrRoot);

        assertEq(weirollComponent.allowedInstrRoot(), newAllowedInstrRoot);
    }

    function test_SetMaxPositionIncreaseLossBps_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        weirollComponent.setMaxPositionIncreaseLossBps(0);
    }

    function test_SetMaxPositionIncreaseLossBps_RevertWhen_InvalidBpsValue() public {
        vm.expectRevert(Errors.InvalidBpsValue.selector);
        vm.prank(address(safe));
        weirollComponent.setMaxPositionIncreaseLossBps(10_001);
    }

    function test_SetMaxPositionIncreaseLossBps() public {
        uint256 newMaxPositionIncreaseLossBps = 300;

        vm.expectEmit(false, false, false, true, address(weirollComponent));
        emit IWeirollComponent.MaxPositionIncreaseLossBpsChanged(
            DEFAULT_MAX_POS_INCREASE_LOSS_BPS, newMaxPositionIncreaseLossBps
        );
        vm.prank(address(safe));
        weirollComponent.setMaxPositionIncreaseLossBps(newMaxPositionIncreaseLossBps);

        assertEq(weirollComponent.maxPositionIncreaseLossBps(), newMaxPositionIncreaseLossBps);
    }

    function test_SetMaxPositionDecreaseLossBps_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        weirollComponent.setMaxPositionDecreaseLossBps(0);
    }

    function test_SetMaxPositionDecreaseLossBps_RevertWhen_InvalidBpsValue() public {
        vm.expectRevert(Errors.InvalidBpsValue.selector);
        vm.prank(address(safe));
        weirollComponent.setMaxPositionDecreaseLossBps(10_001);
    }

    function test_SetMaxPositionDecreaseLossBps() public {
        uint256 newMaxPositionDecreaseLossBps = 500;

        vm.expectEmit(false, false, false, true, address(weirollComponent));
        emit IWeirollComponent.MaxPositionDecreaseLossBpsChanged(
            DEFAULT_MAX_POS_DECREASE_LOSS_BPS, newMaxPositionDecreaseLossBps
        );
        vm.prank(address(safe));
        weirollComponent.setMaxPositionDecreaseLossBps(newMaxPositionDecreaseLossBps);

        assertEq(weirollComponent.maxPositionDecreaseLossBps(), newMaxPositionDecreaseLossBps);
    }

    function test_SetInstrCooldownDuration_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        weirollComponent.setInstrCooldownDuration(0);
    }

    function test_SetInstrCooldownDuration() public {
        uint256 newInstrCooldownDuration = 30 seconds;

        vm.expectEmit(false, false, false, true, address(weirollComponent));
        emit IWeirollComponent.InstrCooldownDurationChanged(DEFAULT_INSTR_COOLDOWN_DURATION, newInstrCooldownDuration);
        vm.prank(address(safe));
        weirollComponent.setInstrCooldownDuration(newInstrCooldownDuration);

        assertEq(weirollComponent.instrCooldownDuration(), newInstrCooldownDuration);
    }
}

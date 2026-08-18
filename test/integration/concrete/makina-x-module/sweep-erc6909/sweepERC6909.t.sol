// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {MockERC6909} from "test/mocks/MockERC6909.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract SweepERC6909_Integration_Concrete_Test is Integration_Concrete_Test {
    uint256 internal constant TEST_ID = 42;

    MockERC6909 internal multiTokenA;

    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        multiTokenA = new MockERC6909();
    }

    function test_RevertWhen_ReentrantCall() public {
        multiTokenA.mint(address(makinaXModule), TEST_ID, 1e18);

        multiTokenA.scheduleReenter(
            MockERC6909.Type.Before,
            address(makinaXModule),
            abi.encodeCall(IMakinaXModule.sweepERC6909, (address(multiTokenA), TEST_ID))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(safe));
        makinaXModule.sweepERC6909(address(multiTokenA), TEST_ID);
    }

    function test_RevertGiven_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.sweepERC6909(address(0), 0);
    }

    function test_SweepERC6909() public {
        uint256 amount = 3e18;

        multiTokenA.mint(address(makinaXModule), TEST_ID, amount);

        vm.prank(address(safe));
        makinaXModule.sweepERC6909(address(multiTokenA), TEST_ID);

        assertEq(multiTokenA.balanceOf(address(makinaXModule), TEST_ID), 0);
        assertEq(multiTokenA.balanceOf(address(safe), TEST_ID), amount);
    }
}

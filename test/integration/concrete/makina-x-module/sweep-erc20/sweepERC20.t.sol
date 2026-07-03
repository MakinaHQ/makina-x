// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract SweepERC20_Integration_Concrete_Test is Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        deal(address(tokenA), address(makinaXModule), 1e18, true);

        tokenA.scheduleReenter(
            MockERC20.Type.Before, address(makinaXModule), abi.encodeCall(IMakinaXModule.sweepERC20, (address(tokenA)))
        );

        vm.expectRevert();
        vm.prank(address(safe));
        makinaXModule.sweepERC20(address(tokenA));
    }

    function test_RevertGiven_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.sweepERC20(address(0));
    }

    function test_SweepERC20() public {
        uint256 amount = 3e18;

        deal(address(tokenA), address(makinaXModule), amount, true);

        vm.prank(address(safe));
        makinaXModule.sweepERC20(address(tokenA));

        assertEq(tokenA.balanceOf(address(makinaXModule)), 0);
        assertEq(tokenA.balanceOf(address(safe)), amount);
    }
}

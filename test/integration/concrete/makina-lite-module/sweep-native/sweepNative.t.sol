// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaLiteModule} from "src/interfaces/IMakinaLiteModule.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract SweepNative_Integration_Concrete_Test is Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        deal(address(tokenA), address(makinaLiteModule), 1e18, true);

        tokenA.scheduleReenter(
            MockERC20.Type.Before, address(makinaLiteModule), abi.encodeCall(IMakinaLiteModule.sweepNative, ())
        );

        vm.expectRevert();
        vm.prank(address(safe));
        makinaLiteModule.sweepERC20(address(tokenA));
    }

    function test_RevertGiven_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaLiteModule.sweepNative();
    }

    function test_RevertGiven_SweepNativeFailed() public {
        safe.setRevertOnReceive(true);

        vm.expectRevert(Errors.SweepNativeFailed.selector);
        vm.prank(address(safe));
        makinaLiteModule.sweepNative();
    }

    function test_SweepNative() public {
        uint256 amount = 3e18;

        deal(address(makinaLiteModule), amount);

        vm.prank(address(safe));
        makinaLiteModule.sweepNative();

        assertEq(address(makinaLiteModule).balance, 0);
        assertEq(address(safe).balance, amount);
    }
}

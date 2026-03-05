// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockDex} from "test/mocks/MockDex.sol";
import {ISwapComponent} from "src/interfaces/ISwapComponent.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract Swap_Integration_Concrete_Test is Integration_Concrete_Test {
    function setUp() public override {
        Integration_Concrete_Test.setUp();

        deal(address(tokenB), address(dex), 1e20, true);
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1;
        deal(address(tokenA), address(safe), inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        tokenA.scheduleReenter(
            MockERC20.Type.Before, address(makinaLiteModule), abi.encodeCall(ISwapComponent.swap, (order))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_ModuleSuspended() public {
        vm.prank(address(dao));
        makinaLiteModule.suspend();

        ISwapComponent.SwapOrder memory order;

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.swap(order);

        vm.prank(address(safe));
        makinaLiteModule.pause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_ModulePaused() public {
        vm.prank(address(safe));
        makinaLiteModule.pause();

        ISwapComponent.SwapOrder memory order;

        vm.expectRevert(Errors.Paused.selector);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_CallerNotOperator() public {
        ISwapComponent.SwapOrder memory order;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_InsufficientBalance() public {
        uint256 inputAmount = 1e18;

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: bytes(""),
            inputToken: address(tokenB),
            outputToken: address(0),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(safe), 0, inputAmount)
        );
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_TargetsNotSet() public {
        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID + 1,
            data: bytes(""),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(address(operator));
        makinaLiteModule.swap(order);

        vm.prank(address(safe));
        makinaLiteModule.setSwapperTargets(TEST_SWAPPER_ID, address(1), address(0));
        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);

        vm.prank(operator);
        makinaLiteModule.swap(order);

        vm.prank(address(safe));
        makinaLiteModule.setSwapperTargets(TEST_SWAPPER_ID, address(0), address(1));

        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_SwapperExecutionFails() public {
        deal(address(tokenB), address(dex), 0, true);

        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.SwapFailed.selector);
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_AmountOutTooLow() public {
        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), inputAmount);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.expectRevert(Errors.AmountOutTooLow.selector);
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_Swap_WithoutFee() public {
        vm.prank(dao);
        makinaLiteModule.setSwapFeeRate(0);

        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), inputAmount);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaLiteModule.swap(order);

        assertEq(tokenB.balanceOf(address(safe)), previewSwap);
        assertEq(tokenB.balanceOf(dao), 0);
    }

    function test_Swap_WithFee() public {
        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), inputAmount);
        uint256 expectedFee = previewSwap * DEFAULT_SWAP_FEE_RATE / 1e18;

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaLiteModule.swap(order);

        assertEq(tokenB.balanceOf(address(safe)), previewSwap - expectedFee);
        assertEq(tokenB.balanceOf(dao), expectedFee);
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered_WhileInLockDownMode() public whileInLockdownMode {
        uint256 inputAmount = 1e18;

        deal(address(tokenA), address(safe), inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.prank(address(safe));
        makinaLiteModule.clearFeedRoute(address(tokenA));

        // input token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenA)));
        vm.prank(operator);
        makinaLiteModule.swap(order);

        vm.startPrank(address(safe));
        makinaLiteModule.setFeedRoute(address(tokenA), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        makinaLiteModule.clearFeedRoute(address(tokenB));
        vm.stopPrank();

        // output token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenB)));
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInLockDownMode() public whileInLockdownMode {
        dex.setQuote(address(tokenA), address(tokenB), 10_000 - DEFAULT_MAX_SWAP_LOSS_BPS - 1, PRICE_B_A * 10_000);

        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(operator);
        makinaLiteModule.swap(order);
    }

    function test_Swap_WhileInLockDownMode() public whileInLockdownMode {
        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        dex.setQuote(address(tokenA), address(tokenB), 1, 1);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), inputAmount);
        uint256 expectedFee = previewSwap * DEFAULT_SWAP_FEE_RATE / 1e18;

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectEmit(true, true, true, true, address(makinaLiteModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaLiteModule.swap(order);

        assertEq(tokenB.balanceOf(address(safe)), previewSwap - expectedFee);
        assertEq(tokenB.balanceOf(dao), expectedFee);
    }
}

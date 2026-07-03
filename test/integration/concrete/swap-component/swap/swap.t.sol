// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockDex} from "test/mocks/MockDex.sol";
import {IMakinaXGovernable} from "src/interfaces/IMakinaXGovernable.sol";
import {ISwapComponent} from "src/interfaces/ISwapComponent.sol";

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
            MockERC20.Type.Before, address(makinaXModule), abi.encodeCall(ISwapComponent.swap, (order))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.swap(order);
    }

    function test_RevertWhen_NotOperational() public {
        ISwapComponent.SwapOrder memory order;

        // module paused
        vm.prank(guardian);
        makinaXModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaXModule.swap(order);

        // module suspended + paused
        vm.prank(dao);
        makinaXModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.swap(order);

        // module suspended
        vm.prank(guardian);
        makinaXModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.swap(order);
    }

    function test_RevertGiven_CallerNotOperator() public {
        ISwapComponent.SwapOrder memory order;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.swap(order);
    }

    function test_RevertGiven_InvalidInputToken() public {
        ISwapComponent.SwapOrder memory order;

        vm.expectRevert(Errors.InvalidInputToken.selector);
        vm.prank(operator);
        makinaXModule.swap(order);
    }

    function test_RevertGiven_TransferFromSafeFailed() public {
        tokenA.setReturnsFalseOnTransfer(true);

        ISwapComponent.SwapOrder memory order;
        order.inputToken = address(tokenA);

        vm.expectRevert(Errors.TransferFromSafeFailed.selector);
        vm.prank(operator);
        makinaXModule.swap(order);
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
        makinaXModule.swap(order);
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
        makinaXModule.swap(order);

        vm.prank(address(safe));
        makinaXModule.setSwapperTargets(TEST_SWAPPER_ID, address(1), address(0));
        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);

        vm.prank(operator);
        makinaXModule.swap(order);

        vm.prank(address(safe));
        makinaXModule.setSwapperTargets(TEST_SWAPPER_ID, address(0), address(1));

        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(operator);
        makinaXModule.swap(order);
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
        makinaXModule.swap(order);
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
        makinaXModule.swap(order);
    }

    function test_Swap_WithoutFee() public {
        vm.prank(dao);
        makinaXModule.setSwapFeeRate(0);

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

        vm.expectEmit(true, true, true, true, address(makinaXModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaXModule.swap(order);

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

        vm.expectEmit(true, true, true, true, address(makinaXModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaXModule.swap(order);

        assertEq(tokenB.balanceOf(address(safe)), previewSwap - expectedFee);
        assertEq(tokenB.balanceOf(dao), expectedFee);
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered_WhileInFencedMode() public whileInFencedMode {
        _test_RevertGiven_PriceFeedRouteNotRegistered();
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered_WhileInWalledMode() public whileInWalledMode {
        _test_RevertGiven_PriceFeedRouteNotRegistered();
    }

    function test_RevertGiven_OngoingCooldown_WhileInFencedMode() public {
        _test_RevertGiven_OngoingCooldown(IMakinaXGovernable.OperatingMode.FENCED);
    }

    function test_RevertGiven_OngoingCooldown_WhileInWalledMode() public {
        _test_RevertGiven_OngoingCooldown(IMakinaXGovernable.OperatingMode.WALLED);
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInFencedMode() public whileInFencedMode {
        _test_RevertGiven_MaxValueLossExceeded();
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInWalledMode() public whileInWalledMode {
        _test_RevertGiven_MaxValueLossExceeded();
    }

    function test_Swap_WhileInFencedMode() public whileInFencedMode {
        _test_Swap_WhileInNonOpenMode();
    }

    function test_Swap_WhileInWalledMode() public whileInWalledMode {
        _test_Swap_WhileInNonOpenMode();
    }

    ///
    /// Shared test logic
    ///

    function _test_RevertGiven_PriceFeedRouteNotRegistered() internal {
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
        makinaXModule.clearFeedRoute(address(tokenA));

        // input token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenA)));
        vm.prank(operator);
        makinaXModule.swap(order);

        vm.startPrank(address(safe));
        makinaXModule.setFeedRoute(address(tokenA), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        makinaXModule.clearFeedRoute(address(tokenB));
        vm.stopPrank();

        // output token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenB)));
        vm.prank(operator);
        makinaXModule.swap(order);
    }

    function _test_RevertGiven_OngoingCooldown(IMakinaXGovernable.OperatingMode mode) internal {
        uint256 inputAmount = 1e18;
        deal(address(tokenA), address(safe), 3 * inputAmount, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        // execute a swap while in open mode
        vm.prank(operator);
        makinaXModule.swap(order);

        // set non-open operating mode
        vm.prank(address(safe));
        makinaXModule.setOperatingMode(mode);

        // execute swap to trigger cooldown
        vm.prank(operator);
        makinaXModule.swap(order);

        // try executing again while cooldown is ongoing
        vm.expectRevert(Errors.OngoingCooldown.selector);
        vm.prank(operator);
        makinaXModule.swap(order);
    }

    function _test_RevertGiven_MaxValueLossExceeded() internal {
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
        makinaXModule.swap(order);
    }

    function _test_Swap_WhileInNonOpenMode() internal {
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

        vm.expectEmit(true, true, true, true, address(makinaXModule));
        emit ISwapComponent.Swap(TEST_SWAPPER_ID, address(tokenA), address(tokenB), inputAmount, previewSwap);
        vm.prank(operator);
        makinaXModule.swap(order);

        assertEq(tokenB.balanceOf(address(safe)), previewSwap - expectedFee);
        assertEq(tokenB.balanceOf(dao), expectedFee);
    }
}

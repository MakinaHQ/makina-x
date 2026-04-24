// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {ISwapComponent} from "src/interfaces/ISwapComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockDex} from "test/mocks/MockDex.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract Harvest_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function setUp() public override {
        WeirollComponent_Integration_Concrete_Test.setUp();

        deal(address(tokenB), address(dex), 1e20, true);
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 harvestAmount = 1e18;
        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders;

        tokenA.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaLiteModule),
            abi.encodeCall(IWeirollComponent.harvest, (instruction, swapOrders))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_NotOperational() public {
        IWeirollComponent.Instruction memory instruction;
        ISwapComponent.SwapOrder[] memory swapOrders;

        // module paused
        vm.prank(guardian);
        makinaLiteModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        // module suspended + paused
        vm.prank(dao);
        makinaLiteModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        // module suspended
        vm.prank(guardian);
        makinaLiteModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_CallerNotOperator() public {
        IWeirollComponent.Instruction memory instruction;
        ISwapComponent.SwapOrder[] memory swapOrders;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_InstructionNonHarvestingType() public {
        IWeirollComponent.Instruction memory instruction =
            _build4626AccountingInstruction(address(safe), VAULT_POS_ID, address(vault));
        ISwapComponent.SwapOrder[] memory swapOrders;
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_ProofInvalid() public {
        vm.startPrank(operator);

        uint256 harvestAmount = 1e18;
        IWeirollComponent.Instruction memory instruction;
        ISwapComponent.SwapOrder[] memory swapOrders;

        // use wrong reward contract
        instruction = _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenB), harvestAmount);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        // use wrong commands
        instruction = _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        delete instruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        // use wrong state
        instruction = _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        delete instruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        // use wrong bitmap
        instruction = _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        instruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        makinaLiteModule.harvest(instruction, swapOrders);

        vm.stopPrank();

        // use new root
        vm.prank(address(safe));
        makinaLiteModule.setAllowedInstrRoot(keccak256(abi.encodePacked("newRoot")));
        instruction = _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapperExecutionFails() public {
        deal(address(tokenB), address(dex), 0, true);

        uint256 harvestAmount = 1e18;
        deal(address(tokenA), address(safe), harvestAmount, true);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.SwapFailed.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapAmountOutTooLow() public {
        uint256 harvestAmount = 1e18;
        deal(address(tokenA), address(safe), harvestAmount, true);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), harvestAmount);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.expectRevert(Errors.AmountOutTooLow.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_Harvest_NoSwap() public {
        _test_Harvest_NoSwap();
    }

    function test_Harvest_WithSwap_WithoutFee() public {
        vm.prank(dao);
        makinaLiteModule.setSwapFeeRate(0);

        uint256 harvestAmount = 1e18;
        uint256 previewOutputAmount = dex.previewSwap(address(tokenA), address(tokenB), harvestAmount);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount
        });

        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
        assertEq(tokenA.balanceOf(address(safe)), 0);
        assertEq(tokenB.balanceOf(address(safe)), previewOutputAmount);
    }

    function test_Harvest_WithSwap_WithFee() public {
        _test_Harvest_WithSwap_WithFee();
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered_WithSwap_WhileInLockDownMode() public whileInLockdownMode {
        uint256 harvestAmount = 1e18;

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: 0
        });

        vm.prank(address(safe));
        makinaLiteModule.clearFeedRoute(address(tokenA));

        // input token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenA)));
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);

        vm.startPrank(address(safe));
        makinaLiteModule.setFeedRoute(address(tokenA), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        makinaLiteModule.clearFeedRoute(address(tokenB));
        vm.stopPrank();

        // output token not registered
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(tokenB)));
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInLockDownMode() public whileInLockdownMode {
        dex.setQuote(address(tokenA), address(tokenB), 10_000 - DEFAULT_MAX_SWAP_LOSS_BPS - 1, PRICE_B_A * 10_000);

        uint256 harvestAmount = 1e18;
        deal(address(tokenA), address(safe), harvestAmount, true);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapperExecutionFails_WhileInLockdownMode() public whileInLockdownMode {
        deal(address(tokenB), address(dex), 0, true);

        uint256 harvestAmount = 1e18;
        deal(address(tokenA), address(safe), harvestAmount, true);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.SwapFailed.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapAmountOutTooLow_WhileInLockDownMode() public whileInLockdownMode {
        uint256 harvestAmount = 1e18;
        deal(address(tokenA), address(safe), harvestAmount, true);

        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), harvestAmount);

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.expectRevert(Errors.AmountOutTooLow.selector);
        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
    }

    function test_Harvest_NoSwap_WhileInLockDownMode() public whileInLockdownMode {
        _test_Harvest_NoSwap();
    }

    function test_Harvest_WithSwap_WhileInLockDownMode() public whileInLockdownMode {
        _test_Harvest_WithSwap_WithFee();
    }

    ///
    /// Shared test logic
    ///

    function _test_Harvest_NoSwap() internal {
        uint256 harvestAmount = 1e18;
        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](0);

        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
        assertEq(tokenA.balanceOf(address(safe)), harvestAmount);
    }

    function _test_Harvest_WithSwap_WithFee() internal {
        uint256 harvestAmount = 1e18;
        uint256 previewSwap = dex.previewSwap(address(tokenA), address(tokenB), harvestAmount);
        uint256 expectedFee = previewSwap * DEFAULT_SWAP_FEE_RATE / 1e18;

        IWeirollComponent.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(safe), address(tokenA), harvestAmount);
        ISwapComponent.SwapOrder[] memory swapOrders = new ISwapComponent.SwapOrder[](1);
        swapOrders[0] = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), harvestAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: harvestAmount,
            minOutputAmount: previewSwap
        });

        vm.prank(operator);
        makinaLiteModule.harvest(instruction, swapOrders);
        assertEq(tokenA.balanceOf(address(safe)), 0);
        assertEq(tokenB.balanceOf(address(safe)), previewSwap - expectedFee);
    }
}

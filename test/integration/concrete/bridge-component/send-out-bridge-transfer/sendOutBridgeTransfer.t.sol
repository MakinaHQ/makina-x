// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IBridgeComponent} from "src/interfaces/IBridgeComponent.sol";
import {IMakinaXGovernable} from "src/interfaces/IMakinaXGovernable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";
import {MockCctpV2TokenMessenger} from "test/mocks/MockCctpV2TokenMessenger.sol";
import {IMockAcrossSpokePool} from "test/mocks/IMockAcrossSpokePool.sol";

import {BridgeComponent_Integration_Concrete_Test} from "../BridgeComponent.t.sol";

contract SendOutBridgeTransfer_Integration_Concrete_Test is BridgeComponent_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 3e18;
        uint256 minOutputAmount = 999e15;

        deal(address(tokenA), address(safe), 3e18, true);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: CCTP_V2_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(tokenA),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD)
        });

        tokenA.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaXModule),
            abi.encodeCall(IBridgeComponent.sendOutBridgeTransfer, (order))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertWhen_NotOperational() public {
        IBridgeComponent.BridgeOrder memory order;

        // module paused
        vm.prank(guardian);
        makinaXModule.pause();

        vm.expectRevert(Errors.Paused.selector);
        makinaXModule.sendOutBridgeTransfer(order);

        // module suspended + paused
        vm.prank(dao);
        makinaXModule.suspend();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.sendOutBridgeTransfer(order);

        // module suspended
        vm.prank(guardian);
        makinaXModule.unpause();

        vm.expectRevert(Errors.Suspended.selector);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertWhen_CallerNotOperator() public {
        IBridgeComponent.BridgeOrder memory order;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertWhen_BridgeEncoderDoesNotExist() public {
        IBridgeComponent.BridgeOrder memory order;

        vm.expectRevert(Errors.BridgeEncoderDoesNotExist.selector);
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertGiven_InvalidInputToken() public {
        IBridgeComponent.BridgeOrder memory order;
        order.bridgeId = CCTP_V2_BRIDGE_ID;

        vm.expectRevert(Errors.InvalidInputToken.selector);
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertGiven_TransferFromSafeFailed() public {
        tokenA.setReturnsFalseOnTransfer(true);

        IBridgeComponent.BridgeOrder memory order;
        order.bridgeId = CCTP_V2_BRIDGE_ID;
        order.inputToken = address(tokenA);

        vm.expectRevert(Errors.TransferFromSafeFailed.selector);
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function test_RevertGiven_OngoingCooldown_WhileInFencedMode() public {
        _test_RevertGiven_OngoingCooldown_WhileInNonOpenMode(IMakinaXGovernable.OperatingMode.FENCED);
    }

    function test_RevertGiven_OngoingCooldown_WhileInWalledMode() public {
        _test_RevertGiven_OngoingCooldown_WhileInNonOpenMode(IMakinaXGovernable.OperatingMode.WALLED);
    }

    function test_RevertGiven_RecipientNotWhitelisted_WhileInFencedMode() public whileInFencedMode {
        _test_RevertGiven_RecipientNotWhitelisted_WhileInNonOpenMode();
    }

    function test_RevertGiven_RecipientNotWhitelisted_WhileInWalledMode() public whileInWalledMode {
        _test_RevertGiven_RecipientNotWhitelisted_WhileInNonOpenMode();
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInFencedMode() public whileInFencedMode {
        _test_RevertGiven_MaxValueLossExceeded_WhileInNonOpenMode();
    }

    function test_RevertGiven_MaxValueLossExceeded_WhileInWalledMode() public whileInWalledMode {
        _test_RevertGiven_MaxValueLossExceeded_WhileInNonOpenMode();
    }

    function test_SendOutBridgeTransfer_AcrossV4() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000);

        address outputToken = makeAddr("outputToken");

        deal(address(tokenA), address(safe), inputAmount, true);

        vm.prank(dao);
        acrossV4BridgeEncoder.addRoute(address(tokenA), L2_CHAIN_ID, outputToken);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: ACROSS_V4_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(tokenA),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(outputToken, ACROSS_V4_FILL_DEADLINE_OFFSET)
        });

        uint256 transferId = acrossV4SpokePool.numberOfDeposits();

        vm.expectEmit(false, false, false, true, address(acrossV4SpokePool));
        emit IMockAcrossSpokePool.Deposit(
            bytes32(uint256(uint160(address(tokenA)))),
            bytes32(uint256(uint160(address(outputToken)))),
            inputAmount,
            minOutputAmount,
            L2_CHAIN_ID,
            transferId,
            uint32(block.timestamp),
            uint32(block.timestamp + ACROSS_V4_FILL_DEADLINE_OFFSET),
            0,
            bytes32(uint256(uint160(address(safe)))),
            bytes32(uint256(uint160(address(safe)))),
            bytes32(0),
            ""
        );

        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);

        assertEq(tokenA.balanceOf(address(safe)), 0);
        assertEq(tokenA.balanceOf(address(makinaXModule)), 0);
        assertEq(tokenA.balanceOf(address(acrossV4SpokePool)), inputAmount);
    }

    function test_SendOutBridgeTransfer_LayerZeroV2_NativeOFT() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000);
        uint256 maxValue = (DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS + DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS)
            * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;

        deal(address(oft), address(safe), inputAmount, true);
        deal(address(makinaXModule), maxValue);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: LAYER_ZERO_V2_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(oft),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oft), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, maxValue)
        });

        vm.expectEmit(false, false, false, true, address(oft));
        emit MockOFT.Send(
            LAYER_ZERO_V2_L2_CHAIN_ID,
            bytes32(uint256(uint160(address(safe)))),
            inputAmount,
            minOutputAmount,
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS,
            maxValue,
            address(makinaXModule)
        );

        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);

        assertEq(oft.balanceOf(address(safe)), 0);
        assertEq(oft.balanceOf(address(makinaXModule)), 0);
        assertEq(oft.totalSupply(), 0);
        assertEq(address(makinaXModule).balance, 0);
        assertEq(address(oft).balance, maxValue);
    }

    function test_SendOutBridgeTransfer_LayerZeroV2_OFTAdapter() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000);
        uint256 maxValue = (DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS + DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS)
            * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;

        deal(address(tokenA), address(safe), inputAmount, true);
        deal(address(makinaXModule), maxValue);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: LAYER_ZERO_V2_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(tokenA),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oftAdapter), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, maxValue)
        });

        vm.expectEmit(false, false, false, true, address(oftAdapter));
        emit MockOFTAdapter.Send(
            LAYER_ZERO_V2_L2_CHAIN_ID,
            bytes32(uint256(uint160(address(safe)))),
            inputAmount,
            minOutputAmount,
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS,
            maxValue,
            address(makinaXModule)
        );

        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);

        assertEq(tokenA.balanceOf(address(safe)), 0);
        assertEq(tokenA.balanceOf(address(makinaXModule)), 0);
        assertEq(tokenA.balanceOf(address(oftAdapter)), inputAmount);
        assertEq(address(makinaXModule).balance, 0);
        assertEq(address(oftAdapter).balance, maxValue);
    }

    function test_SendOutBridgeTransfer_CctpV2() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000);

        deal(address(tokenA), address(safe), inputAmount, true);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: CCTP_V2_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(tokenA),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD)
        });

        vm.expectEmit(false, false, false, true, address(cctpV2TokenMessenger));
        emit MockCctpV2TokenMessenger.Deposit(
            inputAmount,
            CCTP_V2_SPOKE_DOMAIN,
            bytes32(uint256(uint160(address(safe)))),
            address(tokenA),
            bytes32(0),
            inputAmount - minOutputAmount,
            CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
            hex"636374702d666f72776172640000000000000000000000000000000000000000"
        );

        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);

        assertEq(tokenA.balanceOf(address(safe)), 0);
        assertEq(tokenA.balanceOf(address(makinaXModule)), 0);
        assertEq(tokenA.totalSupply(), 0);
    }

    function _test_RevertGiven_OngoingCooldown_WhileInNonOpenMode(IMakinaXGovernable.OperatingMode mode) internal {
        vm.prank(address(safe));
        makinaXModule.addRecipient(L2_CHAIN_ID, address(safe));

        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000);

        deal(address(tokenA), address(safe), 3 * inputAmount, true);

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: CCTP_V2_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: address(safe),
            inputToken: address(tokenA),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD)
        });

        // set a bridge cooldown duration
        vm.prank(address(safe));
        makinaXModule.setBridgeCooldownDuration(1 minutes);

        // send one transfer while in open mode
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);

        // change operation mode
        vm.prank(address(safe));
        makinaXModule.setOperatingMode(mode);

        vm.startPrank(operator);

        // send a transfer to trigger cooldown
        makinaXModule.sendOutBridgeTransfer(order);

        // try sending another transfer while cooldown is ongoing
        vm.expectRevert(Errors.OngoingCooldown.selector);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function _test_RevertGiven_RecipientNotWhitelisted_WhileInNonOpenMode() internal {
        IBridgeComponent.BridgeOrder memory order;
        order.bridgeId = CCTP_V2_BRIDGE_ID;
        order.destinationChainId = L2_CHAIN_ID;
        order.recipient = address(safe);
        order.inputToken = address(tokenA);

        vm.expectRevert(Errors.RecipientNotWhitelisted.selector);
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }

    function _test_RevertGiven_MaxValueLossExceeded_WhileInNonOpenMode() internal {
        uint256 inputAmount = 3e18;
        deal(address(tokenA), address(safe), inputAmount, true);

        IBridgeComponent.BridgeOrder memory order;
        order.bridgeId = CCTP_V2_BRIDGE_ID;
        order.destinationChainId = L2_CHAIN_ID;
        order.recipient = address(safe);
        order.inputToken = address(tokenA);
        order.inputAmount = inputAmount;
        order.minOutputAmount = (inputAmount * (10_000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10_000) - 1;

        vm.prank(address(safe));
        makinaXModule.addRecipient(L2_CHAIN_ID, address(safe));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(operator);
        makinaXModule.sendOutBridgeTransfer(order);
    }
}

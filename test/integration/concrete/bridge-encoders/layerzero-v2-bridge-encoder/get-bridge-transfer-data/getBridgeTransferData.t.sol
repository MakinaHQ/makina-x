// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";
import {IBridgeComponent} from "src/interfaces/IBridgeComponent.sol";
import {IOFT} from "src/interfaces/IOFT.sol";

import {LayerZeroV2BridgeEncoder_Integration_Concrete_Test} from "../LayerZeroV2BridgeEncoder.t.sol";

contract GetBridgeTransferData_LayerZeroV2BridgeEncoder_Integration_Concrete_Test is
    LayerZeroV2BridgeEncoder_Integration_Concrete_Test
{
    function setUp() public override {
        LayerZeroV2BridgeEncoder_Integration_Concrete_Test.setUp();

        vm.startPrank(address(makinaLiteModule));
    }

    function test_RevertGiven_OftMismatch() public {
        IBridgeComponent.BridgeOrder memory order;
        order.extraData = abi.encode(address(0), uint128(0), uint128(0));

        vm.expectRevert(Errors.OftMismatch.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);

        order.extraData = abi.encode(address(oft), uint128(0), uint128(0));

        vm.expectRevert(Errors.OftMismatch.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }

    function test_RevertGiven_LzEndpointIdNotRegistered() public {
        IBridgeComponent.BridgeOrder memory order;
        order.inputToken = address(oft);
        order.extraData = abi.encode(address(oft), uint128(0), uint128(0));

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }

    function test_RevertGiven_ExceededMaxFee() public {
        uint256 expectedFee = DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;

        IBridgeComponent.BridgeOrder memory order;
        order.inputToken = address(oft);
        order.destinationChainId = L2_CHAIN_ID;
        order.extraData = abi.encode(address(oft), uint128(0), expectedFee - 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.ExceededMaxFee.selector, expectedFee, expectedFee - 1));
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }

    function test_RevertGiven_InvalidLzSentAmount() public {
        uint256 expectedFee = DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;

        IBridgeComponent.BridgeOrder memory order;
        order.inputToken = address(oft);
        order.inputAmount = 1e18;
        order.destinationChainId = L2_CHAIN_ID;
        order.extraData = abi.encode(address(oft), uint128(0), expectedFee);

        oft.setFaultyModeSend(true);

        vm.expectRevert(Errors.InvalidLzSentAmount.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }

    function test_RevertGiven_AmountOutTooLow() public {
        uint256 expectedFee = DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;

        IBridgeComponent.BridgeOrder memory order;
        order.inputToken = address(oft);
        order.inputAmount = 1e18;
        order.minOutputAmount = 999e15;
        order.destinationChainId = L2_CHAIN_ID;
        order.extraData = abi.encode(address(oft), uint128(0), expectedFee);

        oft.setFaultyModeReceive(true);

        vm.expectRevert(Errors.AmountOutTooLow.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }

    function test_GetBridgeTransferData_NativeOFT_WithoutGasOption() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;
        uint256 expectedFee = DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;
        address transferRecipient = makeAddr("transferRecipient");

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: address(oft),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oft), uint128(0), expectedFee)
        });

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: LAYER_ZERO_V2_L2_CHAIN_ID,
            to: bytes32(uint256(uint160(transferRecipient))),
            amountLD: inputAmount,
            minAmountLD: minOutputAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        IOFT.MessagingFee memory mf = IOFT.MessagingFee({nativeFee: expectedFee, lzTokenFee: 0});

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            layerZeroV2BridgeEncoder.getBridgeTransferData(order);
        assertEq(approvalTarget, address(0));
        assertEq(executionTarget, address(oft));
        assertEq(value, expectedFee);
        assertEq(cd, abi.encodeCall(IOFT.send, (sendParam, mf, address(makinaLiteModule))));
    }

    function test_GetBridgeTransferData_NativeOFT_WithGasOption() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;
        uint256 expectedFee = (DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS + DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS)
            * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;
        address transferRecipient = makeAddr("transferRecipient");

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: address(oft),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oft), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, expectedFee)
        });

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: LAYER_ZERO_V2_L2_CHAIN_ID,
            to: bytes32(uint256(uint160(transferRecipient))),
            amountLD: inputAmount,
            minAmountLD: minOutputAmount,
            extraOptions: abi.encodePacked(bytes6(0x000301001101), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS),
            composeMsg: "",
            oftCmd: ""
        });

        IOFT.MessagingFee memory mf = IOFT.MessagingFee({nativeFee: expectedFee, lzTokenFee: 0});

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            layerZeroV2BridgeEncoder.getBridgeTransferData(order);
        assertEq(approvalTarget, address(0));
        assertEq(executionTarget, address(oft));
        assertEq(value, expectedFee);
        assertEq(cd, abi.encodeCall(IOFT.send, (sendParam, mf, address(makinaLiteModule))));
    }

    function test_GetBridgeTransferData_OFTAdapter_WithoutGasOption() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;
        uint256 expectedFee = DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;
        address transferRecipient = makeAddr("transferRecipient");

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oftAdapter), uint128(0), expectedFee)
        });

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: LAYER_ZERO_V2_L2_CHAIN_ID,
            to: bytes32(uint256(uint160(transferRecipient))),
            amountLD: inputAmount,
            minAmountLD: minOutputAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        IOFT.MessagingFee memory mf = IOFT.MessagingFee({nativeFee: expectedFee, lzTokenFee: 0});

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            layerZeroV2BridgeEncoder.getBridgeTransferData(order);
        assertEq(approvalTarget, address(oftAdapter));
        assertEq(executionTarget, address(oftAdapter));
        assertEq(value, expectedFee);
        assertEq(cd, abi.encodeCall(IOFT.send, (sendParam, mf, address(makinaLiteModule))));
    }

    function test_GetBridgeTransferData_OFTAdapter_WithGasOption() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;
        uint256 expectedFee = (DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS + DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS)
            * DEFAULT_LAYER_ZERO_V2_GAS_PRICE;
        address transferRecipient = makeAddr("transferRecipient");

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(address(oftAdapter), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, expectedFee)
        });

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: LAYER_ZERO_V2_L2_CHAIN_ID,
            to: bytes32(uint256(uint160(transferRecipient))),
            amountLD: inputAmount,
            minAmountLD: minOutputAmount,
            extraOptions: abi.encodePacked(bytes6(0x000301001101), DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS),
            composeMsg: "",
            oftCmd: ""
        });

        IOFT.MessagingFee memory mf = IOFT.MessagingFee({nativeFee: expectedFee, lzTokenFee: 0});

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            layerZeroV2BridgeEncoder.getBridgeTransferData(order);
        assertEq(approvalTarget, address(oftAdapter));
        assertEq(executionTarget, address(oftAdapter));
        assertEq(value, expectedFee);
        assertEq(cd, abi.encodeCall(IOFT.send, (sendParam, mf, address(makinaLiteModule))));
    }

    function test_RevertGiven_OftNotRegistered_WhileInLockdownMode() public {
        vm.stopPrank();
        vm.prank(address(safe));
        makinaLiteModule.setLockdownMode(true);

        vm.startPrank(address(makinaLiteModule));

        IBridgeComponent.BridgeOrder memory order;
        order.extraData = abi.encode(address(0), uint128(0), uint128(0));

        vm.expectRevert(Errors.OftNotRegistered.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);

        order.extraData = abi.encode(address(oft), uint128(0), uint128(0));

        vm.expectRevert(Errors.OftNotRegistered.selector);
        layerZeroV2BridgeEncoder.getBridgeTransferData(order);
    }
}

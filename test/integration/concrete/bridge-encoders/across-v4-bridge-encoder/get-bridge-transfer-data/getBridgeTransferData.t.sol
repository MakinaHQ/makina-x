// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";
import {IAcrossV4SpokePool} from "src/interfaces/IAcrossV4SpokePool.sol";
import {IBridgeComponent} from "src/interfaces/IBridgeComponent.sol";

import {AcrossV4BridgeEncoder_Integration_Concrete_Test} from "../AcrossV4BridgeEncoder.t.sol";

contract GetBridgeTransferData_AcrossV4BridgeEncoder_Integration_Concrete_Test is
    AcrossV4BridgeEncoder_Integration_Concrete_Test
{
    function test_GetBridgeTransferData_RouteNotRegistered() public {
        IBridgeComponent.BridgeOrder memory order;
        order.extraData = abi.encode(address(0), uint32(0));

        vm.prank(address(makinaXModule));
        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            acrossV4BridgeEncoder.getBridgeTransferData(order);

        assertEq(approvalTarget, acrossV4SpokePool);
        assertEq(executionTarget, acrossV4SpokePool);
        assertEq(value, 0);
        assertEq(
            cd,
            abi.encodeCall(
                IAcrossV4SpokePool.depositV3Now,
                (address(safe), address(0), address(0), address(0), 0, 0, 0, address(0), 0, 0, "")
            )
        );
    }

    function test_GetBridgeTransferData_RouteRegistered() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        address outputToken = makeAddr("outputToken");
        address transferRecipient = makeAddr("transferRecipient");

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(outputToken, ACROSS_V4_FILL_DEADLINE_OFFSET)
        });

        vm.prank(address(makinaXModule));
        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            acrossV4BridgeEncoder.getBridgeTransferData(order);

        assertEq(approvalTarget, acrossV4SpokePool);
        assertEq(executionTarget, acrossV4SpokePool);
        assertEq(value, 0);
        assertEq(
            cd,
            abi.encodeCall(
                IAcrossV4SpokePool.depositV3Now,
                (
                    address(safe),
                    transferRecipient,
                    address(tokenB),
                    outputToken,
                    inputAmount,
                    minOutputAmount,
                    L2_CHAIN_ID,
                    address(0),
                    ACROSS_V4_FILL_DEADLINE_OFFSET,
                    0,
                    ""
                )
            )
        );
    }

    function test_RevertGiven_RouteNotRegistered_WhileInFencedMode() public whileInFencedMode {
        _test_RevertGiven_RouteNotRegistered_WhileInNonOpenMode();
    }

    function test_RevertGiven_RouteNotRegistered_WhileInWalledMode() public whileInWalledMode {
        _test_RevertGiven_RouteNotRegistered_WhileInNonOpenMode();
    }

    function _test_RevertGiven_RouteNotRegistered_WhileInNonOpenMode() internal {
        IBridgeComponent.BridgeOrder memory order;
        order.extraData = abi.encode(address(0), uint32(0));

        vm.expectRevert(Errors.RouteNotRegistered.selector);
        vm.prank(address(makinaXModule));
        acrossV4BridgeEncoder.getBridgeTransferData(order);
    }
}

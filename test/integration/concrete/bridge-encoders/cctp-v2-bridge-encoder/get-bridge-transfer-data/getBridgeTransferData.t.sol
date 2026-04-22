// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IBridgeComponent} from "src/interfaces/IBridgeComponent.sol";
import {ICctpV2TokenMessenger} from "src/interfaces/ICctpV2TokenMessenger.sol";

import {CctpV2BridgeEncoder_Integration_Concrete_Test} from "../CctpV2BridgeEncoder.t.sol";

contract GetBridgeTransferData_CctpV2BridgeEncoder_Integration_Concrete_Test is
    CctpV2BridgeEncoder_Integration_Concrete_Test
{
    function test_RevertGiven_CctpV2DomainRegistered() public {
        IBridgeComponent.BridgeOrder memory order;

        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeEncoder.getBridgeTransferData(order, false);
    }

    function test_RevertWhen_MinOutputAmountExceedsInputAmount() public {
        IBridgeComponent.BridgeOrder memory order;
        order.destinationChainId = L2_CHAIN_ID;
        order.inputAmount = 1e18;
        order.minOutputAmount = 1e18 + 1;

        vm.expectRevert(Errors.MinOutputAmountExceedsInputAmount.selector);
        cctpV2BridgeEncoder.getBridgeTransferData(order, false);
    }

    function test_GetBridgeTransferData_EmptyParams() public view {
        _test_GetBridgeTransferData_EmptyParams(false);
    }

    function test_GetBridgeTransferData() public view {
        _test_GetBridgeTransferData(false);
    }

    function test_GetBridgeTransferData_EmptyParams_WhileInLockdownMode() public view {
        _test_GetBridgeTransferData_EmptyParams(true);
    }

    function test_GetBridgeTransferData_WhileInLockdownMode() public view {
        _test_GetBridgeTransferData(true);
    }

    function _test_GetBridgeTransferData_EmptyParams(bool lockdownMode) internal view {
        IBridgeComponent.BridgeOrder memory order;
        order.destinationChainId = L2_CHAIN_ID;
        order.extraData = abi.encode(0);

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            cctpV2BridgeEncoder.getBridgeTransferData(order, lockdownMode);

        assertEq(approvalTarget, cctpV2TokenMessenger);
        assertEq(executionTarget, cctpV2TokenMessenger);
        assertEq(value, 0);
        assertEq(
            cd,
            abi.encodeCall(
                ICctpV2TokenMessenger.depositForBurnWithHook,
                (
                    0,
                    CCTP_V2_SPOKE_DOMAIN,
                    bytes32(0),
                    address(0),
                    bytes32(0),
                    0,
                    0,
                    hex"636374702d666f72776172640000000000000000000000000000000000000000"
                )
            )
        );
    }

    function _test_GetBridgeTransferData(bool lockdownMode) internal view {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        IBridgeComponent.BridgeOrder memory order = IBridgeComponent.BridgeOrder({
            bridgeId: DUMMY_BRIDGE_ID,
            destinationChainId: L2_CHAIN_ID,
            recipient: transferRecipient,
            inputToken: baseToken,
            inputAmount: inputAmount,
            minOutputAmount: minOutputAmount,
            extraData: abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD)
        });

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            cctpV2BridgeEncoder.getBridgeTransferData(order, lockdownMode);

        assertEq(approvalTarget, cctpV2TokenMessenger);
        assertEq(executionTarget, cctpV2TokenMessenger);
        assertEq(value, 0);
        assertEq(
            cd,
            abi.encodeCall(
                ICctpV2TokenMessenger.depositForBurnWithHook,
                (
                    inputAmount,
                    CCTP_V2_SPOKE_DOMAIN,
                    bytes32(uint256(uint160(transferRecipient))),
                    baseToken,
                    bytes32(0),
                    inputAmount - minOutputAmount,
                    CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
                    hex"636374702d666f72776172640000000000000000000000000000000000000000"
                )
            )
        );
    }
}

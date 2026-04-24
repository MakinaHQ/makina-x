// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IBridgeComponent} from "src/interfaces/IBridgeComponent.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract BridgeComponent_Unit_Concrete_Test is Unit_Concrete_Test {
    IBridgeComponent internal bridgeComponent;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        bridgeComponent = IBridgeComponent(address(makinaLiteModule));
    }
}

contract Getters_Setters_BridgeComponent_Unit_Concrete_Test is BridgeComponent_Unit_Concrete_Test {
    function test_SetMaxBridgeLossBps_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeComponent.setMaxBridgeLossBps(0, 0);
    }

    function test_SetMaxBridgeLossBps_RevertWhen_InvalidBpsValue() public {
        vm.expectRevert(Errors.InvalidBpsValue.selector);
        vm.prank(address(safe));
        bridgeComponent.setMaxBridgeLossBps(0, 10_001);
    }

    function test_SetMaxBridgeLossBps() public {
        uint256 newMaxBridgeLossBps = 300;

        assertEq(bridgeComponent.getMaxBridgeLossBps(DUMMY_BRIDGE_ID), 0);

        vm.expectEmit(true, true, true, false, address(bridgeComponent));
        emit IBridgeComponent.MaxBridgeLossBpsChanged(DUMMY_BRIDGE_ID, 0, newMaxBridgeLossBps);
        vm.prank(address(safe));
        bridgeComponent.setMaxBridgeLossBps(DUMMY_BRIDGE_ID, newMaxBridgeLossBps);

        assertEq(bridgeComponent.getMaxBridgeLossBps(DUMMY_BRIDGE_ID), newMaxBridgeLossBps);
    }

    function test_AddRecipient_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeComponent.addRecipient(0, address(0));
    }

    function test_AddRecipient_RevertWhen_RecipientAlreadyWhitelisted() public {
        vm.startPrank(address(safe));

        bridgeComponent.addRecipient(L2_CHAIN_ID, address(safe));

        vm.expectRevert(Errors.RecipientAlreadyWhitelisted.selector);
        bridgeComponent.addRecipient(L2_CHAIN_ID, address(safe));
    }

    function test_AddRecipient() public {
        vm.expectEmit(true, true, false, false, address(bridgeComponent));
        emit IBridgeComponent.BridgeTransferRecipientAdded(L2_CHAIN_ID, address(safe));
        vm.prank(address(safe));
        bridgeComponent.addRecipient(L2_CHAIN_ID, address(safe));

        assertTrue(bridgeComponent.isWhitelistedRecipient(L2_CHAIN_ID, address(safe)));
    }

    function test_RemoveRecipient_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeComponent.removeRecipient(0, address(0));
    }

    function test_RemoveRecipient_RevertWhen_RecipientNotWhitelisted() public {
        vm.expectRevert(Errors.RecipientNotWhitelisted.selector);
        vm.prank(address(safe));
        bridgeComponent.removeRecipient(L2_CHAIN_ID, address(safe));
    }

    function test_RemoveRecipient() public {
        vm.startPrank(address(safe));

        bridgeComponent.addRecipient(L2_CHAIN_ID, address(safe));

        vm.expectEmit(true, true, false, false, address(bridgeComponent));
        emit IBridgeComponent.BridgeTransferRecipientRemoved(L2_CHAIN_ID, address(safe));
        bridgeComponent.removeRecipient(L2_CHAIN_ID, address(safe));

        assertFalse(bridgeComponent.isWhitelistedRecipient(L2_CHAIN_ID, address(safe)));
    }
}

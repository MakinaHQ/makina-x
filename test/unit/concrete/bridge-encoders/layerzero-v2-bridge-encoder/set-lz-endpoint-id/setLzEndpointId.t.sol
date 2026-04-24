// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ILayerZeroV2BridgeEncoder} from "src/interfaces/ILayerZeroV2BridgeEncoder.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeEncoder_Unit_Concrete_Test} from "../LayerZeroV2BridgeEncoder.t.sol";

contract SetLzEndpointId_Unit_Concrete_Test is LayerZeroV2BridgeEncoder_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2BridgeEncoder.setLzEndpointId(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        vm.prank(dao);
        layerZeroV2BridgeEncoder.setLzEndpointId(0, 1);
    }

    function test_RevertWhen_ZeroEndpointId() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroLzEndpointId.selector));
        vm.prank(dao);
        layerZeroV2BridgeEncoder.setLzEndpointId(1, 0);
    }

    function test_SetLzEndpointId_DifferentIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeEncoder));
        emit ILayerZeroV2BridgeEncoder.LzEndpointIdRegistered(1, 2);
        layerZeroV2BridgeEncoder.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeEncoder.getLzEndpointId(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzEndpointIdNotRegistered.selector, 2));
        layerZeroV2BridgeEncoder.getLzEndpointId(2);
    }

    function test_SetLzEndpointId_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeEncoder));
        emit ILayerZeroV2BridgeEncoder.LzEndpointIdRegistered(2, 2);
        layerZeroV2BridgeEncoder.setLzEndpointId(2, 2);

        assertEq(layerZeroV2BridgeEncoder.getLzEndpointId(2), 2);
    }

    function test_SetLzEndpointId_ReassignLzEndpointId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeEncoder.setLzEndpointId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeEncoder));
        emit ILayerZeroV2BridgeEncoder.LzEndpointIdRegistered(1, 2);
        layerZeroV2BridgeEncoder.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeEncoder.getLzEndpointId(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzEndpointIdNotRegistered.selector, 2));
        layerZeroV2BridgeEncoder.getLzEndpointId(2);
    }

    function test_SetLzEndpointId_ReassignEvmChainId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeEncoder.setLzEndpointId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeEncoder));
        emit ILayerZeroV2BridgeEncoder.LzEndpointIdRegistered(2, 1);
        layerZeroV2BridgeEncoder.setLzEndpointId(2, 1);

        assertEq(layerZeroV2BridgeEncoder.getLzEndpointId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzEndpointIdNotRegistered.selector, 1));
        layerZeroV2BridgeEncoder.getLzEndpointId(1);
    }
}

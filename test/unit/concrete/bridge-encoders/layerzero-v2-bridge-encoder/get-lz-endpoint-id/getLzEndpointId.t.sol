// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeEncoder_Unit_Concrete_Test} from "../LayerZeroV2BridgeEncoder.t.sol";

contract GetLzEndpointId_Unit_Concrete_Test is LayerZeroV2BridgeEncoder_Unit_Concrete_Test {
    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeEncoder.getLzEndpointId(0);

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeEncoder.getLzEndpointId(1);
    }

    function test_GetLzEndpointId() public {
        vm.prank(dao);
        layerZeroV2BridgeEncoder.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeEncoder.getLzEndpointId(1), 2);
    }
}

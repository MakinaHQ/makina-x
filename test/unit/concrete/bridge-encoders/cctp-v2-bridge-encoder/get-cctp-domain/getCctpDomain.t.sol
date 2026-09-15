// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeEncoder_Unit_Concrete_Test} from "../CctpV2BridgeEncoder.t.sol";

contract GetCctpDomain_Unit_Concrete_Test is CctpV2BridgeEncoder_Unit_Concrete_Test {
    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeEncoder.getCctpDomain(0);

        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeEncoder.getCctpDomain(2);
    }

    function test_GetCctpDomain() public {
        assertEq(cctpV2BridgeEncoder.getCctpDomain(1), 0);

        vm.prank(dao);
        cctpV2BridgeEncoder.setCctpDomain(2, 3);

        assertEq(cctpV2BridgeEncoder.getCctpDomain(2), 3);
    }
}

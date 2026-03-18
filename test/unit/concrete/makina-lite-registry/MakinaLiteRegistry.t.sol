// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaLiteRegistry_Unit_Concrete_Test is Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(registry.authority(), address(accessManager));
    }
}

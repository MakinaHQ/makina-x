// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXContext} from "src/interfaces/IMakinaXContext.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaXContext_Unit_Concrete_Test is Unit_Concrete_Test {
    IMakinaXContext internal makinaContext;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        makinaContext = IMakinaXContext(address(makinaXModule));
    }

    function test_Getters() public view {
        assertEq(makinaContext.registry(), address(registry));
    }
}

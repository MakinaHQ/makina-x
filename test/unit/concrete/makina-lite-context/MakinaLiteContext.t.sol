// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IMakinaLiteContext} from "src/interfaces/IMakinaLiteContext.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MakinaLiteContext_Unit_Concrete_Test is Unit_Concrete_Test {
    IMakinaLiteContext internal makinaContext;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        makinaContext = IMakinaLiteContext(address(makinaLiteModule));
    }

    function test_Getters() public view {
        assertEq(makinaContext.registry(), address(registry));
    }
}

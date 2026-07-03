// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract OracleRegistry_Unit_Concrete_Test is Unit_Concrete_Test {
    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;

    IOracleRegistry internal oracleRegistry;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        baseToken = new MockERC20("Base Token", "BT", 18);
        quoteToken = new MockERC20("Quote Token", "QT", 8);

        oracleRegistry = IOracleRegistry(address(makinaXModule));
    }
}

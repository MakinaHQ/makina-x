// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {MockSafe} from "test/mocks/MockSafe.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, Test {
    address internal deployer;

    address internal dao;

    MockSafe internal safe;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");

        safe = new MockSafe();
    }
}

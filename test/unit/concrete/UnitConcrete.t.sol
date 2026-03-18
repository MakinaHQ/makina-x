// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {MakinaLiteModule} from "src/MakinaLiteModule.sol";

import {Base_Test} from "../../base/Base.t.sol";

abstract contract Unit_Concrete_Test is Base_Test {
    MakinaLiteModule internal makinaLiteModule;

    function setUp() public virtual override {
        Base_Test.setUp();

        makinaLiteModule = new MakinaLiteModule(address(registry), address(safe), dao);
    }
}

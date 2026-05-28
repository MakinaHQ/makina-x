// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {AcrossV4BridgeEncoder} from "src/bridge-encoders/AcrossV4BridgeEncoder.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

abstract contract AcrossV4BridgeEncoder_Integration_Concrete_Test is Integration_Concrete_Test {
    address internal acrossV4SpokePool;

    AcrossV4BridgeEncoder internal acrossV4BridgeEncoder;

    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        acrossV4SpokePool = makeAddr("acrossV4SpokePool");

        acrossV4BridgeEncoder =
            _deployAcrossV4BridgeEncoder(address(accessManager), address(accessManager), acrossV4SpokePool);
    }
}

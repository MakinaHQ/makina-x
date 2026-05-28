// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {LayerZeroV2BridgeEncoder} from "src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

abstract contract LayerZeroV2BridgeEncoder_Integration_Concrete_Test is Integration_Concrete_Test {
    MockOFTAdapter internal oftAdapter;
    MockOFT internal oft;

    LayerZeroV2BridgeEncoder internal layerZeroV2BridgeEncoder;

    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        oftAdapter = new MockOFTAdapter(address(address(tokenB)));
        oft = new MockOFT("Mock OFT", "MOFT");

        layerZeroV2BridgeEncoder = _deployLayerZeroV2BridgeEncoder(address(accessManager), address(accessManager));

        vm.prank(dao);
        layerZeroV2BridgeEncoder.setLzEndpointId(L2_CHAIN_ID, LAYER_ZERO_V2_L2_CHAIN_ID);

        oftAdapter.setVerifyGas(DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS);
        oftAdapter.setGasPrice(DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
        oft.setVerifyGas(DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS);
        oft.setGasPrice(DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
    }
}

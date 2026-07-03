// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {AcrossV4BridgeEncoder} from "src/bridge-encoders/AcrossV4BridgeEncoder.sol";
import {CctpV2BridgeEncoder} from "src/bridge-encoders/CctpV2BridgeEncoder.sol";
import {LayerZeroV2BridgeEncoder} from "src/bridge-encoders/LayerZeroV2BridgeEncoder.sol";

import {IMockAcrossSpokePool} from "test/mocks/IMockAcrossSpokePool.sol";
import {MockCctpV2TokenMessenger} from "test/mocks/MockCctpV2TokenMessenger.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract BridgeComponent_Integration_Concrete_Test is Integration_Concrete_Test {
    AcrossV4BridgeEncoder internal acrossV4BridgeEncoder;
    CctpV2BridgeEncoder internal cctpV2BridgeEncoder;
    LayerZeroV2BridgeEncoder internal layerZeroV2BridgeEncoder;

    IMockAcrossSpokePool internal acrossV4SpokePool;

    MockOFTAdapter internal oftAdapter;
    MockOFT internal oft;

    MockCctpV2TokenMessenger internal cctpV2TokenMessenger;

    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        acrossV4SpokePool = IMockAcrossSpokePool(_deployCode(getMockAcrossSpokePoolCode(), 0));

        oftAdapter = new MockOFTAdapter(address(tokenA));
        oft = new MockOFT("Mock OFT", "MOFT");

        oftAdapter.setVerifyGas(DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS);
        oftAdapter.setGasPrice(DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
        oft.setVerifyGas(DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS);
        oft.setGasPrice(DEFAULT_LAYER_ZERO_V2_GAS_PRICE);

        cctpV2TokenMessenger = new MockCctpV2TokenMessenger(CCTP_V2_FEE_MILLI_BPS);

        acrossV4BridgeEncoder =
            _deployAcrossV4BridgeEncoder(address(accessManager), address(accessManager), address(acrossV4SpokePool));
        layerZeroV2BridgeEncoder = _deployLayerZeroV2BridgeEncoder(address(accessManager), address(accessManager));
        cctpV2BridgeEncoder =
            _deployCctpV2BridgeEncoder(address(accessManager), address(accessManager), address(cctpV2TokenMessenger));

        vm.startPrank(dao);
        registry.setBridgeEncoder(ACROSS_V4_BRIDGE_ID, address(acrossV4BridgeEncoder));
        registry.setBridgeEncoder(LAYER_ZERO_V2_BRIDGE_ID, address(layerZeroV2BridgeEncoder));
        registry.setBridgeEncoder(CCTP_V2_BRIDGE_ID, address(cctpV2BridgeEncoder));

        layerZeroV2BridgeEncoder.setLzEndpointId(L2_CHAIN_ID, LAYER_ZERO_V2_L2_CHAIN_ID);
        cctpV2BridgeEncoder.setCctpDomain(L2_CHAIN_ID, CCTP_V2_SPOKE_DOMAIN);
        vm.stopPrank();

        vm.startPrank(address(safe));
        makinaXModule.setMaxBridgeLossBps(ACROSS_V4_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);
        makinaXModule.setMaxBridgeLossBps(LAYER_ZERO_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);
        makinaXModule.setMaxBridgeLossBps(CCTP_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);
        vm.stopPrank();
    }
}

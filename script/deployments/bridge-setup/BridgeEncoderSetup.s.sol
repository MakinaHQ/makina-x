// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// console logging is used intentionally to expose the encoder call calldata in view mode
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IAcrossV4BridgeEncoder} from "../../../src/interfaces/IAcrossV4BridgeEncoder.sol";
import {ICctpV2BridgeEncoder} from "../../../src/interfaces/ICctpV2BridgeEncoder.sol";
import {ILayerZeroV2BridgeEncoder} from "../../../src/interfaces/ILayerZeroV2BridgeEncoder.sol";

/// @notice Shared logic to configure the MakinaX bridge encoders on a given chain.
/// @dev One child contract per chain (see the `bridge-setup/` folder) pins the local chain id via
///      `_localChainId()`; all cross-chain reference data lives in the single `_chains()` table below.
///
///      For the local chain, this script registers:
///        - Across V4: USDC and WETH routes to every other Across-supported chain.
///        - CCTP V2:   the CCTP domain of every other CCTP-supported chain (Ethereum is auto-registered).
///        - LayerZero V2: the endpoint id of every other LayerZero-supported chain.
///
///      The encoder setters are `restricted`, so the broadcasting account must be authorized in the
///      AccessManager for those selectors (the ADMIN_ROLE by default).
///
///      Encoder addresses are deterministic (CreateX) and identical on every chain; they are taken from
///      script/deployments/outputs/makina-x-infra/*-Test-Pre-v110.json.
///
/// Env vars:
///   VIEW_MODE (optional)   - if true, logs each call's target + calldata instead of broadcasting
///                            (e.g. to submit the batch from a multisig / Safe)
///   TEST_SENDER (optional) - account to broadcast from
abstract contract BridgeEncoderSetup is Script {
    struct ChainConfig {
        uint256 chainId;
        string name;
        address usdc; // native USDC (address(0) if unavailable)
        address weth; // wrapped ETH (address(0) if unavailable)
        uint32 cctpDomain; // Circle CCTP V2 domain id
        bool cctpSupported; // whether CCTP V2 supports this chain
        uint32 lzEid; // LayerZero V2 endpoint id (0 if unsupported)
        bool acrossSupported; // whether Across supports this chain
    }

    struct Call {
        address target;
        bytes data;
    }

    address internal constant ACROSS_V4_ENCODER = 0x2fB97323511e50eA6A62f2bF30Be9b254517D586;
    address internal constant LAYER_ZERO_V2_ENCODER = 0x44e22aD5F637FFE6B62D6e4a0b635e87509c48Fb;
    address internal constant CCTP_V2_ENCODER = 0x97430094dA8C0e37830834cf77e5D29baBb2347f;

    /// @dev Ethereum's CCTP domain (0) is auto-registered on the encoder and cannot be set again.
    uint256 internal constant ETHEREUM_CHAIN_ID = 1;

    bool public viewMode;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);
    }

    /// @dev The chain this script runs against. Overridden by each per-chain child contract.
    function _localChainId() internal pure virtual returns (uint256);

    function run() public {
        uint256 localChainId = _localChainId();
        if (!viewMode) {
            require(block.chainid == localChainId, "wrong chain for --rpc-url");
        }

        ChainConfig[] memory chains = _chains();
        ChainConfig memory local = _find(chains, localChainId);

        Call[] memory calls = _buildCalls(local, chains);

        if (viewMode) {
            _logCalls(calls);
            return;
        }

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        _executeCalls(calls);

        vm.stopBroadcast();
    }

    /// @dev Single source of truth for cross-chain reference data. Edit here to add/adjust chains.
    function _chains() internal pure returns (ChainConfig[] memory chains) {
        chains = new ChainConfig[](5);

        // Ethereum Mainnet
        chains[0] = ChainConfig({
            chainId: 1,
            name: "Ethereum",
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            cctpDomain: 0,
            cctpSupported: true,
            lzEid: 30101,
            acrossSupported: true
        });

        // Arbitrum One
        chains[1] = ChainConfig({
            chainId: 42161,
            name: "Arbitrum",
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            cctpDomain: 3,
            cctpSupported: true,
            lzEid: 30110,
            acrossSupported: true
        });

        // Base
        chains[2] = ChainConfig({
            chainId: 8453,
            name: "Base",
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            weth: 0x4200000000000000000000000000000000000006,
            cctpDomain: 6,
            cctpSupported: true,
            lzEid: 30184,
            acrossSupported: true
        });

        // Polygon PoS
        chains[3] = ChainConfig({
            chainId: 137,
            name: "Polygon",
            usdc: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359,
            weth: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            cctpDomain: 7,
            cctpSupported: true,
            lzEid: 30109,
            acrossSupported: true
        });

        // HyperEVM (Hyperliquid). Native gas token is HYPE, not ETH, and there is no canonical WETH that
        // Across bridges here; WETH is left unset so only USDC Across routes are registered for this chain.
        chains[4] = ChainConfig({
            chainId: 999,
            name: "HyperEVM",
            usdc: 0xb88339CB7199b77E23DB6E890353E22632Ba630f,
            weth: address(0),
            cctpDomain: 19,
            cctpSupported: true,
            lzEid: 30367,
            acrossSupported: true
        });
    }

    /// @dev Builds the encoder registration calls for the local chain against every other chain.
    function _buildCalls(ChainConfig memory local, ChainConfig[] memory chains)
        internal
        pure
        returns (Call[] memory calls)
    {
        uint256 n = chains.length;
        Call[] memory buf = new Call[](4 * n); // over-allocated: up to 2 Across + 1 CCTP + 1 LZ per foreign chain
        uint256 k;

        for (uint256 i; i < n; ++i) {
            ChainConfig memory f = chains[i];
            if (f.chainId == local.chainId) {
                continue;
            }

            // Across V4: USDC and WETH routes (only where both ends support Across and hold the token).
            if (local.acrossSupported && f.acrossSupported) {
                if (local.usdc != address(0) && f.usdc != address(0)) {
                    buf[k] = Call(
                        ACROSS_V4_ENCODER,
                        abi.encodeCall(IAcrossV4BridgeEncoder.addRoute, (local.usdc, f.chainId, f.usdc))
                    );
                    ++k;
                }
                if (local.weth != address(0) && f.weth != address(0)) {
                    buf[k] = Call(
                        ACROSS_V4_ENCODER,
                        abi.encodeCall(IAcrossV4BridgeEncoder.addRoute, (local.weth, f.chainId, f.weth))
                    );
                    ++k;
                }
            }

            // CCTP V2: register the foreign domain (Ethereum's domain 0 is auto-registered / protected).
            if (local.cctpSupported && f.cctpSupported && f.chainId != ETHEREUM_CHAIN_ID) {
                buf[k] = Call(
                    CCTP_V2_ENCODER, abi.encodeCall(ICctpV2BridgeEncoder.setCctpDomain, (f.chainId, f.cctpDomain))
                );
                ++k;
            }

            // LayerZero V2: register the foreign endpoint id.
            if (local.lzEid != 0 && f.lzEid != 0) {
                buf[k] = Call(
                    LAYER_ZERO_V2_ENCODER,
                    abi.encodeCall(ILayerZeroV2BridgeEncoder.setLzEndpointId, (f.chainId, f.lzEid))
                );
                ++k;
            }
        }

        calls = new Call[](k);
        for (uint256 i; i < k; ++i) {
            calls[i] = buf[i];
        }
    }

    function _find(ChainConfig[] memory chains, uint256 chainId) internal pure returns (ChainConfig memory) {
        for (uint256 i; i < chains.length; ++i) {
            if (chains[i].chainId == chainId) {
                return chains[i];
            }
        }
        revert("local chain not in table");
    }

    function _executeCalls(Call[] memory calls) internal {
        for (uint256 i; i < calls.length; ++i) {
            Address.functionCall(calls[i].target, calls[i].data);
        }
    }

    function _logCalls(Call[] memory calls) internal pure {
        for (uint256 i; i < calls.length; ++i) {
            console2.log("Target (BridgeEncoder):", calls[i].target);
            console2.log("Calldata:");
            console2.logBytes(calls[i].data);
        }
    }
}

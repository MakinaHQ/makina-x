// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ICctpV2BridgeEncoder} from "../../src/interfaces/ICctpV2BridgeEncoder.sol";
import {ILayerZeroV2BridgeEncoder} from "../../src/interfaces/ILayerZeroV2BridgeEncoder.sol";

import {SetupMakinaX} from "./SetupMakinaX.s.sol";

/// @notice Shared logic to configure the MakinaX bridge encoders on a given chain.
/// @dev One child contract per chain (see the `bridge-setup/` folder) pins the local chain id via
///      `_localChainId()`; all cross-chain reference data lives in the single `_chains()` table below.
///
///      For the local chain, this script registers:
///        - CCTP V2: the CCTP domain of every other CCTP-supported chain (Ethereum is auto-registered).
///        - LayerZero V2: the endpoint id of every other LayerZero-supported chain.
///
///      Encoder addresses are read from the infra output file (`BridgeEncoders`, keyed by bridge id).
///      See `SetupMakinaX` for the env vars.
abstract contract SetupBridgeEncoders is SetupMakinaX {
    struct ChainConfig {
        uint256 chainId;
        string name;
        uint32 cctpDomain; // Circle CCTP V2 domain id
        bool cctpSupported; // whether CCTP V2 supports this chain
        uint32 lzEid; // LayerZero V2 endpoint id (0 if unsupported)
    }

    /// @dev Ethereum's CCTP domain (0) is auto-registered on the encoder and cannot be set again.
    uint256 internal constant ETHEREUM_CHAIN_ID = 1;

    /// @dev The chain this script runs against. Overridden by each per-chain child contract.
    function _localChainId() internal pure virtual returns (uint256);

    function _calls() internal view override returns (Call[] memory) {
        uint256 localChainId = _localChainId();
        if (!viewMode) {
            require(block.chainid == localChainId, "wrong chain for --rpc-url");
        }

        ChainConfig[] memory chains = _chains();
        return _buildCalls(_find(chains, localChainId), chains);
    }

    function _targetLabel() internal pure override returns (string memory) {
        return "Target (BridgeEncoder):";
    }

    /// @dev Single source of truth for cross-chain reference data. Edit here to add/adjust chains.
    function _chains() internal pure returns (ChainConfig[] memory chains) {
        chains = new ChainConfig[](13);

        // Ethereum Mainnet
        chains[0] = ChainConfig({chainId: 1, name: "Ethereum", cctpDomain: 0, cctpSupported: true, lzEid: 30101});

        // Arbitrum One
        chains[1] = ChainConfig({chainId: 42161, name: "Arbitrum", cctpDomain: 3, cctpSupported: true, lzEid: 30110});

        // Base
        chains[2] = ChainConfig({chainId: 8453, name: "Base", cctpDomain: 6, cctpSupported: true, lzEid: 30184});

        // Polygon PoS
        chains[3] = ChainConfig({chainId: 137, name: "Polygon", cctpDomain: 7, cctpSupported: true, lzEid: 30109});

        // HyperEVM (Hyperliquid)
        chains[4] = ChainConfig({chainId: 999, name: "HyperEVM", cctpDomain: 19, cctpSupported: true, lzEid: 30367});

        // OP Mainnet
        chains[5] = ChainConfig({chainId: 10, name: "Optimism", cctpDomain: 2, cctpSupported: true, lzEid: 30111});

        // Avalanche C-Chain
        chains[6] = ChainConfig({chainId: 43114, name: "Avalanche", cctpDomain: 1, cctpSupported: true, lzEid: 30106});

        // Unichain
        chains[7] = ChainConfig({chainId: 130, name: "Unichain", cctpDomain: 10, cctpSupported: true, lzEid: 30320});

        // World Chain
        chains[8] = ChainConfig({chainId: 480, name: "Worldchain", cctpDomain: 14, cctpSupported: true, lzEid: 30319});

        // Ink
        chains[9] = ChainConfig({chainId: 57073, name: "Ink", cctpDomain: 21, cctpSupported: true, lzEid: 30339});

        // Monad
        chains[10] = ChainConfig({chainId: 143, name: "Monad", cctpDomain: 15, cctpSupported: true, lzEid: 30390});

        // Robinhood Chain (no CCTP: LayerZero routes only)
        chains[11] = ChainConfig({chainId: 4663, name: "Robinhood", cctpDomain: 0, cctpSupported: false, lzEid: 30416});

        // Plasma (no CCTP: LayerZero routes only)
        chains[12] = ChainConfig({chainId: 9745, name: "Plasma", cctpDomain: 0, cctpSupported: false, lzEid: 30383});
    }

    /// @dev Builds the encoder registration calls for the local chain against every other chain.
    function _buildCalls(ChainConfig memory local, ChainConfig[] memory chains)
        internal
        view
        returns (Call[] memory calls)
    {
        address cctpEncoder = local.cctpSupported ? _encoder(CCTP_V2_BRIDGE_ID) : address(0);
        address lzEncoder = local.lzEid != 0 ? _encoder(LAYER_ZERO_V2_BRIDGE_ID) : address(0);

        uint256 n = chains.length;
        calls = new Call[](2 * n);
        uint256 k;

        for (uint256 i; i < n; ++i) {
            ChainConfig memory f = chains[i];
            if (f.chainId == local.chainId) {
                continue;
            }

            // CCTP V2: register the foreign domain (Ethereum's domain 0 is auto-registered / protected).
            if (local.cctpSupported && f.cctpSupported && f.chainId != ETHEREUM_CHAIN_ID) {
                calls[k] =
                    Call(cctpEncoder, abi.encodeCall(ICctpV2BridgeEncoder.setCctpDomain, (f.chainId, f.cctpDomain)));
                ++k;
            }

            // LayerZero V2: register the foreign endpoint id.
            if (local.lzEid != 0 && f.lzEid != 0) {
                calls[k] =
                    Call(lzEncoder, abi.encodeCall(ILayerZeroV2BridgeEncoder.setLzEndpointId, (f.chainId, f.lzEid)));
                ++k;
            }
        }

        // Resize the array to the actual number of calls.
        assembly {
            mstore(calls, k)
        }
    }

    /// @dev Looks up a deployed bridge encoder by bridge id in the infra output file.
    function _encoder(uint16 bridgeId) internal view returns (address) {
        (uint16[] memory bridgeIds, address[] memory encoders) = _readBridgeEncoders();
        for (uint256 i; i < bridgeIds.length; ++i) {
            if (bridgeIds[i] == bridgeId) {
                return encoders[i];
            }
        }
        revert("bridge encoder not in output");
    }

    function _find(ChainConfig[] memory chains, uint256 chainId) internal pure returns (ChainConfig memory) {
        for (uint256 i; i < chains.length; ++i) {
            if (chains[i].chainId == chainId) {
                return chains[i];
            }
        }
        revert("local chain not in table");
    }
}

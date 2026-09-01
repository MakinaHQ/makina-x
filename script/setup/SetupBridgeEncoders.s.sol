// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// console logging is used to expose the calls' calldata in view mode
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {ICctpV2BridgeEncoder} from "../../src/interfaces/ICctpV2BridgeEncoder.sol";
import {ILayerZeroV2BridgeEncoder} from "../../src/interfaces/ILayerZeroV2BridgeEncoder.sol";

import {IntegrationIds} from "../../test/utils/IntegrationIds.sol";

/// @notice Configures the MakinaX bridge encoders on the connected chain.
/// @dev The local chain is detected via `block.chainid` and must be listed in the `_chains()` table
///      below, which is the single source of truth for cross-chain reference data. Run with the
///      target chain's `--rpc-url`, including in view mode.
///
///      For the local chain, this script registers:
///        - CCTP V2: the CCTP domain of every other CCTP-supported chain (Ethereum is auto-registered).
///        - LayerZero V2: the endpoint ID of every other LayerZero-supported chain.
///
///      Encoder addresses are read from the infra output file (`BridgeEncoders`, keyed by bridge id).
///      The resulting privileged calls are either broadcast, or logged in view mode alongside their
///      `AccessManager.schedule` wrapper.
///
/// Env vars:
///   INFRA_OUTPUT_FILENAME  - infra output file holding the deployed contract addresses
///                            (under script/deploy/outputs/infra/)
///   VIEW_MODE (optional)   - if true, logs each call's target + calldata instead of broadcasting
contract SetupBridgeEncoders is Script, IntegrationIds {
    struct Call {
        address target;
        bytes data;
    }

    struct ChainConfig {
        uint256 chainId;
        string name;
        uint32 cctpDomain; // Circle CCTP V2 domain id
        bool cctpSupported; // whether CCTP V2 supports this chain
        uint32 lzEid; // LayerZero V2 endpoint id (0 if unsupported)
    }

    /// @dev Ethereum's CCTP domain (0) is auto-registered on the encoder and cannot be set again.
    uint256 internal constant ETHEREUM_CHAIN_ID = 1;

    address public accessManager;
    mapping(uint16 bridgeId => address encoder) public bridgeEncoders;

    bool public viewMode;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);
    }

    /// @dev Test hook to set the AccessManager and the bridge encoders explicitly, instead of having `run` resolve
    ///      them from the env vars and the infra output file. Takes the arrays returned by `DeployMakinaX.deployment`.
    function setParams(address _accessManager, uint16[] memory bridgeIds, address[] memory encoders) public {
        require(bridgeIds.length == encoders.length, "bridge ids / encoders length mismatch");

        accessManager = _accessManager;
        for (uint256 i; i < bridgeIds.length; ++i) {
            bridgeEncoders[bridgeIds[i]] = encoders[i];
        }
    }

    function run() public {
        if (accessManager == address(0)) {
            _loadParamsFromEnv();
        }

        ChainConfig[] memory chains = _chains();
        Call[] memory calls = _buildCalls(_find(chains, block.chainid), chains);

        if (viewMode) {
            _logCalls(calls);
            return;
        }

        vm.startBroadcast();

        for (uint256 i; i < calls.length; ++i) {
            Address.functionCall(calls[i].target, calls[i].data);
        }

        vm.stopBroadcast();
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

    /// @dev Returns the bridge encoder set for the bridge id, reverting if unset.
    function _encoder(uint16 bridgeId) internal view returns (address encoder) {
        encoder = bridgeEncoders[bridgeId];
        require(encoder != address(0), "bridge encoder not set");
    }

    /// @dev Reads the AccessManager and the bridge encoders from this script's infra output file. Encoders absent
    ///      from the file are left unset: `_buildCalls` only requires the ones the local chain supports.
    function _loadParamsFromEnv() internal {
        string memory outputJson = vm.readFile(
            string.concat(vm.projectRoot(), "/script/deploy/outputs/infra/", vm.envString("INFRA_OUTPUT_FILENAME"))
        );

        accessManager = vm.parseJsonAddress(outputJson, ".AccessManager");
        bridgeEncoders[CCTP_V2_BRIDGE_ID] = _parseEncoder(outputJson, CCTP_V2_BRIDGE_ID);
        bridgeEncoders[LAYER_ZERO_V2_BRIDGE_ID] = _parseEncoder(outputJson, LAYER_ZERO_V2_BRIDGE_ID);
    }

    /// @dev Looks up a deployed bridge encoder by bridge id in the infra output file, address(0) if absent.
    function _parseEncoder(string memory outputJson, uint16 bridgeId) internal view returns (address) {
        string memory key = string.concat(".BridgeEncoders.", vm.toString(bridgeId));
        return vm.keyExistsJson(outputJson, key) ? vm.parseJsonAddress(outputJson, key) : address(0);
    }

    function _find(ChainConfig[] memory chains, uint256 chainId) internal pure returns (ChainConfig memory) {
        for (uint256 i; i < chains.length; ++i) {
            if (chains[i].chainId == chainId) {
                return chains[i];
            }
        }
        revert(string.concat("unsupported chain id: ", vm.toString(chainId)));
    }

    function _logCalls(Call[] memory calls) internal view {
        console2.log("AccessManager:", accessManager);

        for (uint256 i; i < calls.length; ++i) {
            console2.log("Target (BridgeEncoder):", calls[i].target);
            console2.log("Calldata:");
            console2.logBytes(calls[i].data);

            console2.log("AccessManager schedule calldata:");
            console2.logBytes(abi.encodeCall(IAccessManager.schedule, (calls[i].target, calls[i].data, 0)));

            console2.log("\n");
        }
    }
}

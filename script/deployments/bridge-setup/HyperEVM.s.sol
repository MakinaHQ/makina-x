// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {BridgeEncoderSetup} from "./BridgeEncoderSetup.s.sol";

/// @notice Bridge encoder setup for HyperEVM / Hyperliquid (chain id 999).
contract SetupBridgesHyperEVM is BridgeEncoderSetup {
    function _localChainId() internal pure override returns (uint256) {
        return 999;
    }
}

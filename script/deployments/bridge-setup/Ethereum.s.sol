// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {BridgeEncoderSetup} from "./BridgeEncoderSetup.s.sol";

/// @notice Bridge encoder setup for Ethereum Mainnet (chain id 1).
contract SetupBridgesEthereum is BridgeEncoderSetup {
    function _localChainId() internal pure override returns (uint256) {
        return 1;
    }
}

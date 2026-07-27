// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {SetupBridgeEncoders} from "../SetupBridgeEncoders.s.sol";

/// @notice Bridge encoder setup for Plasma (chain id 9745).
contract SetupBridgeEncodersPlasma is SetupBridgeEncoders {
    function _localChainId() internal pure override returns (uint256) {
        return 9745;
    }
}

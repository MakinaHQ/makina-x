// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {SetupMakinaX} from "./SetupMakinaX.s.sol";

/// @notice Configures the AccessManager function roles for the MakinaX infrastructure.
/// @dev The broadcasting account must have the `ADMIN_ROLE` in the AccessManager provided in the infra input file.
///      See `SetupMakinaX` for the env vars.
contract SetupMakinaXAM is SetupMakinaX {
    function _calls() internal view override returns (Call[] memory) {
        address accessManager = _accessManager();
        (uint16[] memory bridgeIds, address[] memory encoders) = _readBridgeEncoders();

        return _concatCalls(
            _amFunctionRoleCalls(accessManager, _readInfra()),
            _bridgeEncoderAMFunctionRoleCalls(accessManager, bridgeIds, encoders)
        );
    }

    function _targetLabel() internal pure override returns (string memory) {
        return "Target (AccessManager):";
    }
}

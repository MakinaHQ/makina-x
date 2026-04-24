// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBridgeComponent} from "./IBridgeComponent.sol";

interface IBridgeEncoder {
    /// @notice Returns targets, value, and calldata to execute a bridge transfer.
    /// @param order The bridge transfer params.
    /// @param lockdownMode True if the calling module is in lockdown mode, false otherwise.
    /// @return approvalTarget The address of the approval target.
    /// @return executionTarget The address of the execution target.
    /// @return value The value to pass along with the calldata.
    /// @return cd The calldata to execute.
    function getBridgeTransferData(IBridgeComponent.BridgeOrder calldata order, bool lockdownMode)
        external
        view
        returns (address approvalTarget, address executionTarget, uint256 value, bytes memory cd);
}

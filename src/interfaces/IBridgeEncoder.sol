// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgeComponent} from "./IBridgeComponent.sol";

interface IBridgeEncoder {
    /// @notice Returns targets, value, and calldata to execute a bridge transfer.
    /// @dev Intended to be called only by a MakinaXModule instance, from which implementations may read caller state via `msg.sender`.
    /// @param order The bridge transfer params.
    /// @return approvalTarget The address of the approval target.
    /// @return executionTarget The address of the execution target.
    /// @return value The value to pass along with the calldata.
    /// @return cd The calldata to execute.
    function getBridgeTransferData(IBridgeComponent.BridgeOrder calldata order)
        external
        view
        returns (address approvalTarget, address executionTarget, uint256 value, bytes memory cd);
}

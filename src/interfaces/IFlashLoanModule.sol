// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IMorphoFlashLoanCallback} from "./IMorphoFlashLoanCallback.sol";
import {IWeirollComponent} from "./IWeirollComponent.sol";

interface IFlashLoanModule is IMorphoFlashLoanCallback {
    /// @notice The enum for the flash loan providers.
    /// @dev Deprecated entries are intentionally preserved to maintain stable enum indexing
    ///      and avoid breaking compatibility with Makina integrations.
    enum FlashLoanProvider {
        DEPRECATED_0,
        DEPRECATED_1,
        DEPRECATED_2,
        MORPHO,
        DEPRECATED_3
    }

    /// @notice Generic flash loan params.
    /// @param taker The address of the contract that will receive the flash loan.
    /// @param provider The provider of the flash loan.
    /// @param instruction The instruction to execute.
    /// @param token The token to borrow.
    /// @param amount The amount to borrow.
    struct FlashLoanRequest {
        address taker;
        FlashLoanProvider provider;
        IWeirollComponent.Instruction instruction;
        address token;
        uint256 amount;
    }

    /// @notice The function to request a flash loan.
    /// @param request The request for the flash loan.
    function requestFlashLoan(FlashLoanRequest calldata request) external;
}

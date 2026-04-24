// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface ISwapComponent {
    event MaxSwapLossBpsChanged(uint256 oldMaxSwapLossBps, uint256 newMaxSwapLossBps);
    event Swap(
        uint16 indexed swapperId,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );
    event SwapFeeRateChanged(uint256 oldSwapFeeRate, uint256 newSwapFeeRate);
    event SwapperTargetsSet(uint16 indexed swapperId, address approvalTarget, address executionTarget);

    struct SwapperTargets {
        address approvalTarget;
        address executionTarget;
    }

    /// @notice Swap order object.
    /// @param swapperId The ID of the external swap protocol.
    /// @param data The swap calldata to pass to the swapper's execution target.
    /// @param inputToken The input token.
    /// @param outputToken The output token.
    /// @param inputAmount The input amount.
    /// @param minOutputAmount The minimum expected output amount.
    struct SwapOrder {
        uint16 swapperId;
        bytes data;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
    }

    /// @notice Max allowed value loss (in basis points) for token swaps, while in lockdown mode.
    function maxSwapLossBps() external view returns (uint256);

    /// @notice Swap fee rate, 1e18 = 100%.
    function swapFeeRate() external view returns (uint256);

    /// @notice Returns approval and execution targets for a given swapper ID.
    /// @param swapperId The swapper ID.
    /// @return approvalTarget The approval target.
    /// @return executionTarget The execution target.
    function getSwapperTargets(uint16 swapperId) external view returns (address approvalTarget, address executionTarget);

    /// @notice Swaps tokens on behalf of Safe using a given swapper.
    /// @param order The swap order object.
    function swap(SwapOrder calldata order) external;

    /// @notice Sets the maximum allowed value loss (in basis points) for token swaps while in lockdown mode.
    /// @param newMaxSwapLossBps The new maximum swap loss in basis points.
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external;

    /// @notice Sets the swap fee rate.
    /// @param newSwapFeeRate The new swap fee rate, 1e18 = 100%.
    function setSwapFeeRate(uint256 newSwapFeeRate) external;

    /// @notice Sets approval and execution targets for a given swapper ID.
    /// @param swapperId The swapper ID.
    /// @param approvalTarget The approval target.
    /// @param executionTarget The execution target.
    function setSwapperTargets(uint16 swapperId, address approvalTarget, address executionTarget) external;
}

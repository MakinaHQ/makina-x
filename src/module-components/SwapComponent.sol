// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "../libraries/Errors.sol";
import {ISwapComponent} from "../interfaces/ISwapComponent.sol";

abstract contract SwapComponent is ISwapComponent {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    mapping(uint16 swapperId => SwapperTargets targets) private _swapperTargets;

    /// @inheritdoc ISwapComponent
    uint256 public maxSwapLossBps;

    /// @inheritdoc ISwapComponent
    uint256 public swapFeeRate;

    /// @inheritdoc ISwapComponent
    function getSwapperTargets(uint16 swapperId)
        external
        view
        returns (address approvalTarget, address executionTarget)
    {
        SwapperTargets storage targets = _swapperTargets[swapperId];
        return (targets.approvalTarget, targets.executionTarget);
    }

    /// @dev Internal logic to swap tokens using a given swapper.
    function _swap(SwapOrder calldata order, bool lockdownMode) internal returns (uint256) {
        SwapperTargets storage targets = _swapperTargets[order.swapperId];
        address approvalTarget = targets.approvalTarget;
        address executionTarget = targets.executionTarget;

        if (approvalTarget == address(0) || executionTarget == address(0)) {
            revert Errors.SwapperTargetsNotSet();
        }

        uint256 balBefore = IERC20(order.outputToken).balanceOf(address(this));

        IERC20(order.inputToken).forceApprove(approvalTarget, order.inputAmount);
        // solhint-disable-next-line
        (bool success,) = executionTarget.call(order.data);
        if (!success) {
            revert Errors.SwapFailed();
        }
        IERC20(order.inputToken).forceApprove(approvalTarget, 0);

        uint256 outputAmount = IERC20(order.outputToken).balanceOf(address(this)) - balBefore;

        if (outputAmount < order.minOutputAmount) {
            revert Errors.AmountOutTooLow();
        }

        if (lockdownMode) {
            uint256 valOut = _valueOf(order.outputToken, order.inputToken, outputAmount);
            if (valOut < order.inputAmount.mulDiv(MAX_BPS - maxSwapLossBps, MAX_BPS, Math.Rounding.Ceil)) {
                revert Errors.MaxValueLossExceeded();
            }
        }

        emit Swap(order.swapperId, order.inputToken, order.outputToken, order.inputAmount, outputAmount);

        return outputAmount;
    }

    /// @dev Internal logic to set the maximum allowed value loss (in basis points) for token swaps while in lockdown mode.
    function _setMaxSwapLossBps(uint256 newMaxSwapLossBps) internal {
        emit MaxSwapLossBpsChanged(maxSwapLossBps, newMaxSwapLossBps);
        maxSwapLossBps = newMaxSwapLossBps;
    }

    /// @dev Internal logic to set the swap fee rate.
    function _setSwapFeeRate(uint256 newSwapFeeRate) internal {
        emit SwapFeeRateChanged(swapFeeRate, newSwapFeeRate);
        swapFeeRate = newSwapFeeRate;
    }

    /// @dev Internal logic to set approval and execution targets for a given swapper ID.
    function _setSwapperTargets(uint16 swapperId, address approvalTarget, address executionTarget) internal {
        _swapperTargets[swapperId] = SwapperTargets(approvalTarget, executionTarget);
        emit SwapperTargetsSet(swapperId, approvalTarget, executionTarget);
    }

    function _valueOf(address baseToken, address quoteToken, uint256 baseTokenAmount)
        internal
        view
        virtual
        returns (uint256);
}

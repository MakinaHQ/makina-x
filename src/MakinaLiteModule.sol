// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {DecimalsUtils} from "./libraries/DecimalsUtils.sol";
import {IMakinaLiteModule} from "./interfaces/IMakinaLiteModule.sol";
import {IMakinaLiteRegistry} from "./interfaces/IMakinaLiteRegistry.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {Errors} from "./libraries/Errors.sol";
import {MakinaLiteContext} from "./utils/MakinaLiteContext.sol";
import {MakinaLiteGovernable} from "./utils/MakinaLiteGovernable.sol";
import {OracleRegistry, IOracleRegistry} from "./module-components/OracleRegistry.sol";
import {SwapComponent, ISwapComponent} from "./module-components/SwapComponent.sol";

contract MakinaLiteModule is
    MakinaLiteContext,
    MakinaLiteGovernable,
    OracleRegistry,
    SwapComponent,
    ReentrancyGuard,
    IMakinaLiteModule
{
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Full scale value for fee rates
    uint256 private constant MAX_FEE_RATE = 1e18;

    constructor(address registry, address _safe, address _provider, uint256 _maxSwapLossBps, uint256 _swapFeeRate)
        MakinaLiteContext(registry)
        MakinaLiteGovernable(_safe, _provider)
    {
        _checkBps(_maxSwapLossBps);
        _setMaxSwapLossBps(_maxSwapLossBps);

        _checkFeeRate(_swapFeeRate);
        _setSwapFeeRate(_swapFeeRate);
    }

    /// @inheritdoc IOracleRegistry
    function setFeedRoute(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external override onlySafe {
        _setFeedRoute(token, feed1, stalenessThreshold1, feed2, stalenessThreshold2);
    }

    /// @inheritdoc IOracleRegistry
    function clearFeedRoute(address token) external override onlySafe {
        _clearFeedRoute(token);
    }

    /// @inheritdoc IOracleRegistry
    function setFeedStaleThreshold(address feed, uint256 newThreshold) external override onlySafe {
        _setFeedStaleThreshold(feed, newThreshold);
    }

    /// @inheritdoc ISwapComponent
    function swap(ISwapComponent.SwapOrder calldata order) external override nonReentrant whenOperational onlyOperator {
        _swapForSafe(order);
    }

    /// @inheritdoc ISwapComponent
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external override onlySafe {
        _checkBps(newMaxSwapLossBps);
        _setMaxSwapLossBps(newMaxSwapLossBps);
    }

    function setSwapFeeRate(uint256 newSwapFeeRate) external override onlyProvider {
        _checkFeeRate(newSwapFeeRate);
        _setSwapFeeRate(newSwapFeeRate);
    }

    /// @inheritdoc ISwapComponent
    function setSwapperTargets(uint16 swapperId, address approvalTarget, address executionTarget)
        external
        override
        onlySafe
    {
        _setSwapperTargets(swapperId, approvalTarget, executionTarget);
    }

    /// @dev Internal logic to execute swap tokens on behalf of Safe using a given swapper.
    function _swapForSafe(ISwapComponent.SwapOrder calldata order) internal {
        _transferFromSafe(order.inputToken, order.inputAmount);

        uint256 amountOut = _swap(order, lockdownMode);

        uint256 fee = _chargeSwapFee(order.outputToken, amountOut);

        IERC20(order.outputToken).safeTransfer(safe, amountOut - fee);
    }

    /// @dev Returns the value of `baseTokenAmount` of `baseToken` denominated in `quoteToken`,  using the registered price feed.
    function _valueOf(address baseToken, address quoteToken, uint256 baseTokenAmount)
        internal
        view
        override
        returns (uint256)
    {
        uint256 price = getPrice(baseToken, quoteToken);
        return baseTokenAmount.mulDiv(price, 10 ** DecimalsUtils._getDecimals(baseToken));
    }

    /// @dev Approves this contract via a Safe module call to spend `amount` of `token`,
    ///      then pulls the tokens from the Safe.
    ///      Intentionally optimistic: does not check the Safe call result.
    ///      Safety relies on `transferFrom` reverting if approval/allowance is insufficient.
    function _transferFromSafe(address token, uint256 amount) internal {
        ISafe(safe)
            .execTransactionFromModule(
                token, 0, abi.encodeCall(IERC20.approve, (address(this), amount)), ISafe.Operation.Call
            );
        IERC20(token).safeTransferFrom(safe, address(this), amount);
    }

    /// @dev Performs sanity check on a basis points value.
    function _checkBps(uint256 bpsValue) internal pure {
        if (bpsValue > MAX_BPS) {
            revert Errors.InvalidBpsValue();
        }
    }

    /// @dev Performs sanity check on a fee rate.
    function _checkFeeRate(uint256 rate) internal pure {
        if (rate > MAX_FEE_RATE) {
            revert Errors.InvalidFeeRate();
        }
    }

    /// @dev Computes the fee for a given swap output, transfers it to the fee collector, and returns it.
    function _chargeSwapFee(address tokenOut, uint256 amountOut) internal returns (uint256) {
        if (swapFeeRate == 0) {
            return 0;
        }

        uint256 fee = amountOut.mulDiv(swapFeeRate, MAX_FEE_RATE);
        if (fee > 0) {
            address feeCollector = IMakinaLiteRegistry(registry).feeCollector();
            IERC20(tokenOut).safeTransfer(feeCollector, fee);
        }

        return fee;
    }
}

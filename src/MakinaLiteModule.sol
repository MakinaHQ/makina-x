// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BridgeComponent} from "./module-components/BridgeComponent.sol";
import {IBridgeComponent} from "./interfaces/IBridgeComponent.sol";
import {IMakinaLiteModule} from "./interfaces/IMakinaLiteModule.sol";
import {IMakinaLiteRegistry} from "./interfaces/IMakinaLiteRegistry.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {Errors} from "./libraries/Errors.sol";
import {MakinaLiteContext} from "./utils/MakinaLiteContext.sol";
import {MakinaLiteGovernable} from "./utils/MakinaLiteGovernable.sol";
import {OracleRegistry, IOracleRegistry} from "./module-components/OracleRegistry.sol";
import {WeirollComponent, IWeirollComponent} from "./module-components/WeirollComponent.sol";
import {SwapComponent, ISwapComponent} from "./module-components/SwapComponent.sol";

contract MakinaLiteModule is
    MakinaLiteContext,
    MakinaLiteGovernable,
    OracleRegistry,
    WeirollComponent,
    SwapComponent,
    BridgeComponent,
    ReentrancyGuard,
    IMakinaLiteModule
{
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Full scale value for fee rates
    uint256 private constant MAX_FEE_RATE = 1e18;

    constructor(address _registry, address _weirollVm) MakinaLiteContext(_registry) WeirollComponent(_weirollVm) {
        _disableInitializers();
    }

    /// @inheritdoc IMakinaLiteModule
    function initialize(MakinaLiteModuleInitParams calldata params) external override initializer {
        __MakinaLiteGovernable_init(params.safe, params.initialProvider, params.initialOperatingMode);

        _setAllowedInstrRoot(params.initialAllowedInstrRoot);

        _checkBps(params.initialMaxPositionIncreaseLossBps);
        _setMaxPositionIncreaseLossBps(params.initialMaxPositionIncreaseLossBps);

        _checkBps(params.initialMaxPositionDecreaseLossBps);
        _setMaxPositionDecreaseLossBps(params.initialMaxPositionDecreaseLossBps);

        _setInstrCooldownDuration(params.initialInstrCooldownDuration);

        _checkBps(params.initialMaxSwapLossBps);
        _setMaxSwapLossBps(params.initialMaxSwapLossBps);

        _checkFeeRate(params.initialSwapFeeRate);
        _setSwapFeeRate(params.initialSwapFeeRate);

        _setSwapCooldownDuration(params.initialSwapCooldownDuration);
    }

    receive() external payable {}

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

    /// @inheritdoc IWeirollComponent
    function accountForPosition(IWeirollComponent.Instruction calldata instruction)
        external
        override
        nonReentrant
        whenOperational
        onlyOperator
        returns (uint256)
    {
        return _accountForPosition(instruction, true, safe);
    }

    /// @inheritdoc IWeirollComponent
    function accountForPositionBatch(IWeirollComponent.Instruction[] calldata instructions, uint256[] calldata)
        external
        override
        nonReentrant
        whenOperational
        onlyOperator
        returns (uint256[] memory)
    {
        uint256 len = instructions.length;
        uint256[] memory values = new uint256[](len);
        for (uint256 i; i < len; ++i) {
            values[i] = _accountForPosition(instructions[i], true, safe);
        }

        return values;
    }

    /// @inheritdoc IWeirollComponent
    function managePosition(
        IWeirollComponent.Instruction calldata mgmtInstruction,
        IWeirollComponent.Instruction calldata acctInstruction
    ) external override nonReentrant whenOperational onlyOperator returns (uint256, int256) {
        return _managePosition(mgmtInstruction, acctInstruction, operatingMode == OperatingMode.WALLED, safe);
    }

    /// @inheritdoc IWeirollComponent
    function managePositionBatch(
        IWeirollComponent.Instruction[] calldata mgmtInstructions,
        IWeirollComponent.Instruction[] calldata acctInstructions
    ) external override nonReentrant whenOperational onlyOperator returns (uint256[] memory, int256[] memory) {
        uint256 len = mgmtInstructions.length;
        if (len != acctInstructions.length) {
            revert Errors.MismatchedLengths();
        }

        uint256[] memory values = new uint256[](len);
        int256[] memory changes = new int256[](len);

        for (uint256 i; i < len; ++i) {
            (values[i], changes[i]) =
                _managePosition(mgmtInstructions[i], acctInstructions[i], operatingMode == OperatingMode.WALLED, safe);
        }

        return (values, changes);
    }

    /// @inheritdoc IWeirollComponent
    function manageFlashLoan(IWeirollComponent.Instruction calldata instruction, address token, uint256 amount)
        external
        override
    {
        address flashLoanModule = IMakinaLiteRegistry(registry).flashLoanModule();
        _manageFlashLoan(instruction, token, amount, safe, flashLoanModule);
    }

    /// @inheritdoc IWeirollComponent
    function harvest(IWeirollComponent.Instruction calldata instruction, ISwapComponent.SwapOrder[] calldata swapOrders)
        external
        override
        nonReentrant
        whenOperational
        onlyOperator
    {
        _harvest(instruction, safe);

        uint256 len = swapOrders.length;
        for (uint256 i; i < len; ++i) {
            _swapForSafe(swapOrders[i]);
        }
    }

    /// @inheritdoc IWeirollComponent
    function setAllowedInstrRoot(bytes32 newAllowedInstrRoot) external override onlySafe {
        _setAllowedInstrRoot(newAllowedInstrRoot);
    }

    /// @inheritdoc IWeirollComponent
    function setAccountingCurrency(address newAccountingCurrency) external override nonReentrant onlySafe {
        if (!isFeedRouteRegistered(newAccountingCurrency)) {
            revert Errors.PriceFeedRouteNotRegistered(newAccountingCurrency);
        }
        _setAccountingCurrency(newAccountingCurrency);
    }

    /// @inheritdoc IWeirollComponent
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) external override onlySafe {
        _checkBps(newMaxPositionIncreaseLossBps);
        _setMaxPositionIncreaseLossBps(newMaxPositionIncreaseLossBps);
    }

    /// @inheritdoc IWeirollComponent
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) external override onlySafe {
        _checkBps(newMaxPositionDecreaseLossBps);
        _setMaxPositionDecreaseLossBps(newMaxPositionDecreaseLossBps);
    }

    /// @inheritdoc IWeirollComponent
    function setInstrCooldownDuration(uint256 newInstrCooldownDuration) external override onlySafe {
        _setInstrCooldownDuration(newInstrCooldownDuration);
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

    /// @inheritdoc ISwapComponent
    function setSwapCooldownDuration(uint256 newSwapCooldownDuration) external override onlySafe {
        _setSwapCooldownDuration(newSwapCooldownDuration);
    }

    /// @inheritdoc ISwapComponent
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
        if (executionTarget == safe || approvalTarget == safe) {
            revert Errors.InvalidTarget();
        }
        _setSwapperTargets(swapperId, approvalTarget, executionTarget);
    }

    /// @inheritdoc IBridgeComponent
    function sendOutBridgeTransfer(IBridgeComponent.BridgeOrder calldata order)
        external
        override
        nonReentrant
        whenOperational
        onlyOperator
    {
        address encoder = IMakinaLiteRegistry(registry).getBridgeEncoder(order.bridgeId);
        _pullERC20FromSafe(order.inputToken, order.inputAmount, address(this));
        _sendOutBridgeTransfer(order, encoder, operatingMode != OperatingMode.OPEN);
    }

    /// @inheritdoc IBridgeComponent
    function setMaxBridgeLossBps(uint16 bridgeId, uint256 newMaxBridgeLossBps) external override onlySafe {
        _checkBps(newMaxBridgeLossBps);
        _setMaxBridgeLossBps(bridgeId, newMaxBridgeLossBps);
    }

    /// @inheritdoc IBridgeComponent
    function setBridgeCooldownDuration(uint256 newBridgeCooldownDuration) external override onlySafe {
        _setBridgeCooldownDuration(newBridgeCooldownDuration);
    }

    /// @inheritdoc IBridgeComponent
    function addRecipient(uint256 foreignChainId, address recipient) external override onlySafe {
        _addRecipient(foreignChainId, recipient);
    }

    /// @inheritdoc IBridgeComponent
    function removeRecipient(uint256 foreignChainId, address recipient) external override onlySafe {
        _removeRecipient(foreignChainId, recipient);
    }

    /// @inheritdoc IMakinaLiteModule
    function sweepERC20(address token) external nonReentrant onlySafe {
        uint256 bal = IERC20Metadata(token).balanceOf(address(this));
        IERC20Metadata(token).safeTransfer(safe, bal);
    }

    /// @inheritdoc IMakinaLiteModule
    function sweepNative() external nonReentrant onlySafe {
        (bool success,) = safe.call{value: address(this).balance}("");
        if (!success) {
            revert Errors.SweepNativeFailed();
        }
    }

    /// @dev Internal logic to execute token swaps on behalf of Safe using a given swapper.
    function _swapForSafe(ISwapComponent.SwapOrder calldata order) internal {
        _pullERC20FromSafe(order.inputToken, order.inputAmount, address(this));

        uint256 amountOut = _swap(order, operatingMode != OperatingMode.OPEN);

        uint256 fee = _chargeSwapFee(order.outputToken, amountOut);

        IERC20Metadata(order.outputToken).safeTransfer(safe, amountOut - fee);
    }

    /// @dev Returns the value of `baseTokenAmount` of `baseToken` denominated in `quoteToken`, using the registered price route.
    function _valueOf(address baseToken, address quoteToken, uint256 baseTokenAmount)
        internal
        view
        override(WeirollComponent, SwapComponent)
        returns (uint256)
    {
        if (baseToken == quoteToken) {
            return baseTokenAmount;
        }

        uint256 price;
        if (quoteToken == address(0)) {
            price = getReferencePrice(baseToken);
        } else {
            price = getPrice(baseToken, quoteToken);
        }

        return baseTokenAmount.mulDiv(price, 10 ** IERC20Metadata(baseToken).decimals());
    }

    /// @dev Transfers `amount` of ERC20 `token` from the Safe to the flash loan module via a module call.
    function _refundFlashLoan(address token, uint256 amount, address flashLoanModule) internal override {
        _pullERC20FromSafe(token, amount, flashLoanModule);
    }

    /// @dev Transfers `amount` of ERC20 `token` from the Safe to this module via a module call.
    function _pullERC20FromSafe(address token, uint256 amount, address recipient) internal {
        if (token.code.length == 0) {
            revert Errors.InvalidInputToken();
        }

        (bool success, bytes memory returnData) = ISafe(safe)
            .execTransactionFromModuleReturnData(
                token, 0, abi.encodeCall(IERC20.transfer, (recipient, amount)), ISafe.Operation.Call
            );
        returnData = Address.verifyCallResult(success, returnData);
        if (returnData.length > 0 && !abi.decode(returnData, (bool))) {
            revert Errors.TransferFromSafeFailed();
        }
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
            IERC20Metadata(tokenOut).safeTransfer(feeCollector, fee);
        }

        return fee;
    }
}

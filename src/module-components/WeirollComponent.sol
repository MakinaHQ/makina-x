// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";

import {Errors} from "../libraries/Errors.sol";
import {ISafe} from "../interfaces/ISafe.sol";
import {IWeirollVM} from "../interfaces/IWeirollVM.sol";
import {IWeirollComponent} from "../interfaces/IWeirollComponent.sol";

abstract contract WeirollComponent is IWeirollComponent {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using TransientSlot for *;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Flag to indicate end of values in the accounting output state.
    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END = bytes32(type(uint256).max);

    // keccak256(abi.encode(uint256(keccak256("makina.storage.WeirollComponent.managedPositionId")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MANAGED_POSITION_ID_SLOT =
        0xfbb6b868544e1f69cf175881d715d83b048bd3f24bc7e327034891f3b849d600;

    // keccak256(abi.encode(uint256(keccak256("makina.storage.WeirollComponent.isManagedPositionDebt")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant IS_MANAGED_POSITION_DEBT_SLOT =
        0x4e4b4e291d20f6f03003921c4d26de1006021d95c6c1641168790b4e4b3b7200;

    // keccak256(abi.encode(uint256(keccak256("makina.storage.WeirollComponent.isManagingFlashLoan")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant IS_MANAGING_FLASHLOAN_SLOT =
        0x8af85af09dfd26c2dc59ce2f32b0ca3422706a314bdc173e6610c5138eba2b00;

    mapping(bytes32 executionHash => uint256 timestamp) private _lastGuardedExecTimestamps;

    /// @inheritdoc IWeirollComponent
    address public immutable weirollVm;

    /// @inheritdoc IWeirollComponent
    bytes32 public allowedInstrRoot;

    /// @inheritdoc IWeirollComponent
    address public accountingCurrency;

    /// @inheritdoc IWeirollComponent
    uint256 public maxPositionIncreaseLossBps;

    /// @inheritdoc IWeirollComponent
    uint256 public maxPositionDecreaseLossBps;

    /// @inheritdoc IWeirollComponent
    uint256 public instrCooldownDuration;

    constructor(address _weirollVm) {
        weirollVm = _weirollVm;
    }

    /// @dev Manages and accounts for a position by executing the provided instructions.
    function _managePosition(
        Instruction calldata mgmtInstruction,
        Instruction calldata acctInstruction,
        bool guarded,
        address safe
    ) internal returns (uint256 value, int256 change) {
        uint256 posId = mgmtInstruction.positionId;
        if (posId == 0) {
            revert Errors.ZeroPositionId();
        }
        if (mgmtInstruction.instructionType != InstructionType.MANAGEMENT) {
            revert Errors.InvalidInstructionType();
        }
        _checkInstructionIsAllowed(mgmtInstruction);

        MANAGED_POSITION_ID_SLOT.asUint256().tstore(posId);
        IS_MANAGED_POSITION_DEBT_SLOT.asBoolean().tstore(mgmtInstruction.isDebt);

        uint256 valueBefore;

        bool acctInstructionProvided = acctInstruction.commands.length != 0;
        if (acctInstructionProvided) {
            if (posId != acctInstruction.positionId || mgmtInstruction.isDebt != acctInstruction.isDebt) {
                revert Errors.InstructionsMismatch();
            }
            valueBefore = _accountForPosition(acctInstruction, true, safe);
        } else if (guarded) {
            revert Errors.AccountingMandatory();
        }

        uint256 affectedTokensValueBefore;
        if (guarded) {
            affectedTokensValueBefore = _aggregateTokensValue(mgmtInstruction.affectedTokens, safe);
        }

        _execute(mgmtInstruction.commands, mgmtInstruction.state, safe);

        if (acctInstructionProvided) {
            value = _accountForPosition(acctInstruction, false, safe);
            change = int256(value) - int256(valueBefore);

            if (guarded) {
                uint256 affectedTokensValueAfter = _aggregateTokensValue(mgmtInstruction.affectedTokens, safe);

                bool isPositionIncrease = change > 0;

                _checkAndSetCooldown(keccak256(abi.encodePacked(posId, mgmtInstruction.commands, isPositionIncrease)));

                uint256 absChange = isPositionIncrease ? uint256(change) : uint256(-change);
                uint256 maxLossBps = isPositionIncrease ? maxPositionIncreaseLossBps : maxPositionDecreaseLossBps;

                if (affectedTokensValueAfter < affectedTokensValueBefore) {
                    if (change != 0 && mgmtInstruction.isDebt == isPositionIncrease) {
                        revert Errors.InvalidPositionChangeDirection();
                    }
                    _checkPositionMinDelta(absChange, affectedTokensValueBefore - affectedTokensValueAfter, maxLossBps);
                } else {
                    if (change != 0 && mgmtInstruction.isDebt == isPositionIncrease) {
                        _checkPositionMaxDelta(
                            absChange, affectedTokensValueAfter - affectedTokensValueBefore, maxLossBps
                        );
                    }
                }
            }
        }

        MANAGED_POSITION_ID_SLOT.asUint256().tstore(0);
        IS_MANAGED_POSITION_DEBT_SLOT.asBoolean().tstore(false);

        emit PositionManaged(acctInstructionProvided, guarded, posId, value);
    }

    /// @dev Manages and refunds flash loan funds.
    function _manageFlashLoan(
        Instruction calldata instruction,
        address token,
        uint256 amount,
        address safe,
        address flashLoanModule
    ) internal {
        if (IS_MANAGING_FLASHLOAN_SLOT.asBoolean().tload()) {
            revert Errors.ManageFlashLoanReentrantCall();
        }

        if (msg.sender != flashLoanModule) {
            revert Errors.NotFlashLoanModule();
        }

        uint256 managedPositionId = MANAGED_POSITION_ID_SLOT.asUint256().tload();
        if (managedPositionId == 0) {
            revert Errors.DirectManageFlashLoanCall();
        }
        if (instruction.instructionType != InstructionType.FLASHLOAN_MANAGEMENT) {
            revert Errors.InvalidInstructionType();
        }
        if (
            managedPositionId != instruction.positionId
                || IS_MANAGED_POSITION_DEBT_SLOT.asBoolean().tload() != instruction.isDebt
        ) {
            revert Errors.InstructionsMismatch();
        }
        if (instruction.isDebt) {
            revert Errors.InvalidDebtFlag();
        }

        IS_MANAGING_FLASHLOAN_SLOT.asBoolean().tstore(true);

        IERC20(token).safeTransferFrom(flashLoanModule, safe, amount);
        _checkInstructionIsAllowed(instruction);
        _execute(instruction.commands, instruction.state, safe);
        _refundFlashLoan(token, amount, flashLoanModule);

        IS_MANAGING_FLASHLOAN_SLOT.asBoolean().tstore(false);
    }

    /// @dev Computes the accounting value of a position.
    function _accountForPosition(Instruction calldata instruction, bool checks, address safe)
        internal
        returns (uint256)
    {
        if (checks) {
            if (instruction.instructionType != InstructionType.ACCOUNTING) {
                revert Errors.InvalidInstructionType();
            }
            _checkInstructionIsAllowed(instruction);
        }

        uint256[] memory amounts;
        {
            bytes[] memory returnedState = _execute(instruction.commands, instruction.state, safe);
            amounts = _decodeAccountingOutputState(returnedState);
        }

        uint256 currentValue;

        uint256 len = instruction.affectedTokens.length;
        if (amounts.length != len) {
            revert Errors.InvalidAccounting();
        }
        for (uint256 i; i < len; ++i) {
            address token = instruction.affectedTokens[i];
            currentValue += _valueOf(token, accountingCurrency, amounts[i]);
        }

        return currentValue;
    }

    /// @dev Internal logic to harvest one or multiple positions.
    function _harvest(IWeirollComponent.Instruction calldata instruction, address safe) internal {
        if (instruction.instructionType != InstructionType.HARVEST) {
            revert Errors.InvalidInstructionType();
        }
        _checkInstructionIsAllowed(instruction);
        _execute(instruction.commands, instruction.state, safe);
    }

    /// @dev Decodes the output state of an accounting instruction into an array of amounts.
    function _decodeAccountingOutputState(bytes[] memory state) internal pure returns (uint256[] memory) {
        uint256 len = state.length;
        uint256[] memory amounts = new uint256[](len);

        uint256 i;
        for (; i < len; ++i) {
            if (bytes32(state[i]) == ACCOUNTING_OUTPUT_STATE_END) {
                break;
            }
            amounts[i] = uint256(bytes32(state[i]));
        }

        // Resize the array to the actual number of values.
        assembly {
            mstore(amounts, i)
        }

        return amounts;
    }

    /// @dev Checks that absolute position value change is greater than minimum value relative to affected token balance changes and loss tolerance.
    function _checkPositionMinDelta(uint256 positionValChange, uint256 affectedTokensValChange, uint256 maxLossBps)
        internal
        pure
    {
        uint256 minChange = affectedTokensValChange.mulDiv(MAX_BPS - maxLossBps, MAX_BPS, Math.Rounding.Ceil);
        if (positionValChange < minChange) {
            revert Errors.MaxValueLossExceeded();
        }
    }

    /// @dev Checks that absolute position value change is less than maximum value relative to affected token balance changes and loss tolerance.
    function _checkPositionMaxDelta(uint256 positionValChange, uint256 affectedTokensValChange, uint256 maxLossBps)
        internal
        pure
    {
        uint256 maxChange = affectedTokensValChange.mulDiv(MAX_BPS + maxLossBps, MAX_BPS);
        if (positionValChange > maxChange) {
            revert Errors.MaxValueLossExceeded();
        }
    }

    /// @dev Checks if the given instruction is allowed by verifying its Merkle proof against the allowed instructions root.
    /// @param instruction The instruction to check.
    function _checkInstructionIsAllowed(Instruction calldata instruction) internal view {
        bytes32 instructionLeaf = keccak256(
            abi.encode(
                keccak256(
                    abi.encode(
                        keccak256(abi.encodePacked(instruction.commands)),
                        _getStateHash(instruction.state, instruction.stateBitmap),
                        instruction.stateBitmap,
                        instruction.positionId,
                        instruction.isDebt,
                        instruction.groupId,
                        keccak256(abi.encodePacked(instruction.affectedTokens)),
                        keccak256(abi.encodePacked(instruction.positionTokens)),
                        instruction.instructionType
                    )
                )
            )
        );
        if (!MerkleProof.verify(instruction.merkleProof, allowedInstrRoot, instructionLeaf)) {
            revert Errors.InvalidInstructionProof();
        }
    }

    /// @dev Computes a hash of the state array, selectively including elements as specified by a bitmap.
    ///      This enables a Weiroll script to have both fixed and variable parameters.
    /// @param state The state array to hash.
    /// @param bitmap The bitmap where each bit determines whether the corresponding element in state is included or ignored in the hash computation.
    /// @return hash The hash of the state array.
    function _getStateHash(bytes[] calldata state, uint128 bitmap) internal pure returns (bytes32) {
        if (bitmap == uint128(0)) {
            return bytes32(0);
        }

        uint256 len = state.length;
        bytes memory hashInput;

        // Iterate through the state and hash values corresponding to indices marked in the bitmap.
        for (uint256 i; i < len; ++i) {
            // If the bit is set as 1, hash the state value.
            if (bitmap & (0x80000000000000000000000000000000 >> i) != 0) {
                hashInput = bytes.concat(hashInput, keccak256(state[i]));
            }
        }
        return keccak256(hashInput);
    }

    /// @dev Computes the total value of the token balances held by the Safe, priced in given currency.
    function _aggregateTokensValue(address[] calldata tokens, address safe) internal view returns (uint256) {
        uint256 totalValue;
        uint256 atLen = tokens.length;
        for (uint256 i; i < atLen; ++i) {
            address token = tokens[i];
            totalValue += _valueOf(token, accountingCurrency, IERC20(token).balanceOf(safe));
        }
        return totalValue;
    }

    /// @dev Internal logic to set the root of the Merkle tree containing allowed instructions.
    function _setAllowedInstrRoot(bytes32 newAllowedInstrRoot) internal {
        emit AllowedInstrRootChanged(allowedInstrRoot, newAllowedInstrRoot);
        allowedInstrRoot = newAllowedInstrRoot;
    }

    /// @dev Internal logic to set the accounting currency.
    function _setAccountingCurrency(address newAccountingCurrency) internal {
        emit AccountingCurrencyChanged(accountingCurrency, newAccountingCurrency);
        accountingCurrency = newAccountingCurrency;
    }

    /// @dev Internal logic to set the maximum allowed relative value loss for position increases.
    function _setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) internal {
        emit MaxPositionIncreaseLossBpsChanged(maxPositionIncreaseLossBps, newMaxPositionIncreaseLossBps);
        maxPositionIncreaseLossBps = newMaxPositionIncreaseLossBps;
    }

    /// @dev Internal logic to set the maximum allowed relative value loss for position decreases.
    function _setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) internal {
        emit MaxPositionDecreaseLossBpsChanged(maxPositionDecreaseLossBps, newMaxPositionDecreaseLossBps);
        maxPositionDecreaseLossBps = newMaxPositionDecreaseLossBps;
    }

    /// @dev Internal logic to set the cooldown duration for instruction executions.
    function _setInstrCooldownDuration(uint256 newInstrCooldownDuration) internal {
        emit InstrCooldownDurationChanged(instrCooldownDuration, newInstrCooldownDuration);
        instrCooldownDuration = newInstrCooldownDuration;
    }

    /// @dev Instructs the Safe to execute a set of commands via a delegatecall to the Weiroll VM.
    /// @param commands The commands to execute.
    /// @param state The state to pass to the VM.
    /// @param safe The Safe to dispatch the delegatecall.
    /// @return outState The new state after executing the commands.
    function _execute(bytes32[] calldata commands, bytes[] memory state, address safe)
        internal
        returns (bytes[] memory)
    {
        (bool success, bytes memory returnData) = ISafe(safe)
            .execTransactionFromModuleReturnData(
                weirollVm, 0, abi.encodeCall(IWeirollVM.execute, (commands, state)), ISafe.Operation.DelegateCall
            );
        returnData = Address.verifyCallResult(success, returnData);
        return abi.decode(returnData, (bytes[]));
    }

    /// @dev Checks cooldown for a given guarded execution and updates its last timestamp.
    function _checkAndSetCooldown(bytes32 executionHash) internal {
        uint256 timestamp = block.timestamp;
        if (
            _lastGuardedExecTimestamps[executionHash] != 0
                && timestamp - _lastGuardedExecTimestamps[executionHash] < instrCooldownDuration
        ) {
            revert Errors.OngoingCooldown();
        }
        _lastGuardedExecTimestamps[executionHash] = timestamp;
    }

    /// @dev Returns the value of `baseTokenAmount` of `baseToken` denominated in `quoteToken`, using the registered price route.
    function _valueOf(address baseToken, address quoteToken, uint256 baseTokenAmount)
        internal
        view
        virtual
        returns (uint256);

    /// @dev Transfers `amount` of ERC20 `token` from the Safe to the flash loan module via a module call.
    function _refundFlashLoan(address token, uint256 amount, address flashLoanModule) internal virtual;
}

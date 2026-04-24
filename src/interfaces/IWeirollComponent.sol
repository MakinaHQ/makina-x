// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ISwapComponent} from "./ISwapComponent.sol";

interface IWeirollComponent {
    event AllowedInstrRootChanged(bytes32 indexed oldRoot, bytes32 indexed newRoot);
    event AccountingCurrencyChanged(address indexed oldAccountingCurrency, address indexed newAccountingCurrency);
    event MaxPositionIncreaseLossBpsChanged(
        uint256 oldMaxPositionIncreaseLossBps, uint256 newMaxPositionIncreaseLossBps
    );
    event MaxPositionDecreaseLossBpsChanged(
        uint256 oldMaxPositionDecreaseLossBps, uint256 newMaxPositionDecreaseLossBps
    );
    event PositionManaged(
        bool indexed withValuation, bool indexed lockdownMode, uint256 indexed positionId, uint256 value
    );

    enum InstructionType {
        MANAGEMENT,
        ACCOUNTING,
        HARVEST,
        FLASHLOAN_MANAGEMENT
    }

    /// @notice Instruction parameters.
    /// @param positionId The ID of the involved position.
    /// @param isDebt Whether the position is a debt.
    /// @param groupId The ID of the position accounting group.
    ///        Set to 0 if the instruction is not of type ACCOUNTING, or if the involved position is ungrouped.
    /// @param instructionType The type of the instruction.
    /// @param affectedTokens The array of affected tokens.
    /// @param positionTokens The array of position tokens.
    /// @param commands The array of commands.
    /// @param state The array of state.
    /// @param stateBitmap The state bitmap.
    /// @param merkleProof The array of Merkle proof elements.
    struct Instruction {
        uint256 positionId;
        bool isDebt;
        uint256 groupId;
        InstructionType instructionType;
        address[] affectedTokens;
        address[] positionTokens;
        bytes32[] commands;
        bytes[] state;
        uint128 stateBitmap;
        bytes32[] merkleProof;
    }

    /// @notice Address of the Weiroll VM.
    function weirollVm() external view returns (address);

    /// @notice Root of the Merkle tree containing allowed instructions.
    function allowedInstrRoot() external view returns (bytes32);

    /// @notice Currency used to value positions.
    /// @dev If set to address(0), the reference currency of the OracleRegistry is used.
    function accountingCurrency() external view returns (address);

    /// @notice Max allowed value loss (in basis points) when increasing a position, while in lockdown mode.
    function maxPositionIncreaseLossBps() external view returns (uint256);

    /// @notice Max allowed value loss (in basis points) when decreasing a position, while in lockdown mode.
    function maxPositionDecreaseLossBps() external view returns (uint256);

    /// @notice Prices a position.
    /// @dev If the position value goes to zero, it is closed.
    /// @param instruction The accounting instruction.
    /// @return value The new position value.
    function accountForPosition(Instruction calldata instruction) external returns (uint256 value);

    /// @notice Prices a batch of positions.
    /// @param instructions The array of accounting instructions.
    /// @param groupIds Ignored parameter kept to preserve interface compatibility with Makina Core.
    /// @return values The new position values.
    function accountForPositionBatch(Instruction[] calldata instructions, uint256[] calldata groupIds)
        external
        returns (uint256[] memory values);

    /// @notice Manages a position's state through paired management and accounting instructions.
    /// @dev If `acctInstruction` is provided, it is executed before and after the management instruction to
    /// compute the new position value and its signed delta.
    /// @dev In lockdown mode, `acctInstruction` must be provided and value preservation checks are applied using
    /// a validation matrix to prevent economic inconsistencies between position changes and token flows.
    ///
    /// The lockdown mode matrix evaluates three factors to determine required validations:
    /// - Affected Tokens flow - Sign of the change in the Safe's aggregate value of `mgmtInstruction.affectedTokens`
    /// - Debt Position - Whether position represents protocol liability (true) vs asset (false)
    /// - Position Δ direction - Direction of position value change (increase/decrease/null)
    ///
    /// ┌──────────────────────┬───────────────┬──────────────────────┬───────────────────────────┐
    /// │ Affected Tokens flow │ Debt Position │ Position Δ direction │ Action                    │
    /// ├──────────────────────┼───────────────┼──────────────────────┼───────────────────────────┤
    /// │ Outflow              │ No            │ Decrease             │ Revert: Invalid direction │
    /// │ Outflow              │ Yes           │ Increase             │ Revert: Invalid direction │
    /// │ Outflow              │ No            │ Increase / Null      │ Minimum Δ Check           │
    /// │ Outflow              │ Yes           │ Decrease / Null      │ Minimum Δ Check           │
    /// │ Inflow / Null        │ No            │ Decrease             │ Maximum Δ Check           │
    /// │ Inflow / Null        │ Yes           │ Increase             │ Maximum Δ Check           │
    /// │ Inflow / Null        │ No            │ Increase / Null      │ No check (favorable move) │
    /// │ Inflow / Null        │ Yes           │ Decrease / Null      │ No check (favorable move) │
    /// └──────────────────────┴───────────────┴──────────────────────┴───────────────────────────┘
    ///
    /// @param mgmtInstruction The management instruction.
    /// @param acctInstruction The accounting instruction.
    /// @return value The new position value, or 0 if `acctInstruction` was not provided.
    /// @return change The signed position value delta, or 0 if `acctInstruction` was not provided.
    function managePosition(Instruction calldata mgmtInstruction, Instruction calldata acctInstruction)
        external
        returns (uint256 value, int256 change);

    /// @notice Manages a batch of positions.
    /// @dev Convenience function to manage multiple positions in a single transaction.
    /// @param mgmtInstructions The array of management instructions.
    /// @param acctInstructions The array of accounting instructions.
    /// @return values The new position values.
    /// @return changes The changes in the position values.
    function managePositionBatch(Instruction[] calldata mgmtInstructions, Instruction[] calldata acctInstructions)
        external
        returns (uint256[] memory values, int256[] memory changes);

    /// @notice Manages flash loan funds.
    /// @param instruction The flash loan management instruction.
    /// @param token The loan token.
    /// @param amount The loan amount.
    function manageFlashLoan(Instruction calldata instruction, address token, uint256 amount) external;

    /// @notice Harvests one or multiple positions.
    /// @param instruction The harvest instruction.
    /// @param swapOrders The array of swap orders to be executed after the harvest.
    function harvest(Instruction calldata instruction, ISwapComponent.SwapOrder[] calldata swapOrders) external;

    /// @notice Sets the root of the Merkle tree containing allowed instructions.
    /// @param newAllowedInstrRoot The new Merkle root.
    function setAllowedInstrRoot(bytes32 newAllowedInstrRoot) external;

    /// @notice Sets the currency used to value positions.
    /// @param newAccountingCurrency The new currency.
    function setAccountingCurrency(address newAccountingCurrency) external;

    /// @notice Sets the max allowed value loss for position increases.
    /// @param newMaxPositionIncreaseLossBps The new max value loss in basis points.
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) external;

    /// @notice Sets the max allowed value loss for position decreases.
    /// @param newMaxPositionDecreaseLossBps The new max value loss in basis points.
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) external;
}

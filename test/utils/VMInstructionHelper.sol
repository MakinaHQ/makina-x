// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IFlashLoanModule} from "src/interfaces/IFlashLoanModule.sol";
import {IWeirollComponent} from "../../src/interfaces/IWeirollComponent.sol";
import {MerkleProofHelper} from "./MerkleProofHelper.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockBorrowModule} from "../mocks/MockBorrowModule.sol";
import {MockSupplyModule} from "../mocks/MockSupplyModule.sol";

abstract contract VMInstructionHelper is MerkleProofHelper {
    bytes32 internal constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function _buildCommand(bytes4 _selector, bytes1 _flags, bytes6 _input, bytes1 _output, address _target)
        internal
        pure
        returns (bytes32)
    {
        uint256 selector = uint256(bytes32(_selector));
        uint256 flags = uint256(uint8(_flags)) << 216;
        uint256 input = uint256(uint48(_input)) << 168;
        uint256 output = uint256(uint8(_output)) << 160;
        uint256 target = uint256(uint160(_target));

        return bytes32(selector ^ flags ^ input ^ output ^ target);
    }

    function _build4626DepositInstruction(address _safe, uint256 _posId, address _vault, uint256 _assets)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + IERC4626(_vault).asset()
        commands[0] = _buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            IERC4626(_vault).asset()
        );
        // "0x6e553f65010102ffffffffff" + _vault
        commands[1] = _buildCommand(
            IERC4626.deposit.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_vault);
        state[1] = abi.encode(_assets);
        state[2] = abi.encode(_safe);

        bytes32[] memory merkleProof = _getDeposit4626InstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _build4626RedeemInstruction(address _safe, uint256 _posId, address _vault, uint256 _shares)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xba08765201000102ffffffff" + _vault
        commands[0] = _buildCommand(
            IERC4626.redeem.selector,
            0x01, // call
            0x000102ffffff, // 3 inputs at indices 0, 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_shares);
        state[1] = abi.encode(_safe);
        state[2] = abi.encode(_safe);

        uint128 stateBitmap = 0x60000000000000000000000000000000;

        bytes32[] memory merkleProof = _getRedeem4626InstrProof();

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _build4626AccountingInstruction(address _safe, uint256 _posId, address _vault)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        address[] memory positionTokens = new address[](1);
        positionTokens[0] = _vault;

        bytes32[] memory commands = new bytes32[](3);
        // "0x38d52e0f02ffffffffffff00" + _vault
        commands[0] = _buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            _vault
        );
        // "0x70a082310202ffffffffff02" + _vault
        commands[1] = _buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x02, // store fixed size result at index 2 of state
            _vault
        );
        // "0x4cdad5060202ffffffffff00" + _vault
        commands[2] = _buildCommand(
            IERC4626.previewRedeem.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x00, // store fixed size result at index 0 of state
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_safe);

        uint128 stateBitmap = 0x20000000000000000000000000000000;

        bytes32[] memory merkleProof = _getAccounting4626InstrProof();

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.ACCOUNTING,
            affectedTokens,
            positionTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleSupplyInstruction(uint256 _posId, address _supplyModule, uint256 _assets)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + MockSupplyModule(_supplyModule).asset()
        commands[0] = _buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockSupplyModule(_supplyModule).asset()
        );
        // "0x354030230101ffffffffffff" + _supplyModule
        commands[1] = _buildCommand(
            MockSupplyModule.supply.selector,
            0x01, // call
            0x01ffffffffff, // 1 input at indices 1 of state
            0xff, // ignore result
            _supplyModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_supplyModule);
        state[1] = abi.encode(_assets);

        bytes32[] memory merkleProof = _getSupplyMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleWithdrawInstruction(uint256 _posId, address _supplyModule, uint256 _assets)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0x2e1a7d4d0100ffffffffffff" + _supplyModule
        commands[0] = _buildCommand(
            MockSupplyModule.withdraw.selector,
            0x01, // call
            0x00ffffffffff, // 1 input at indices 0 of state
            0xff, // ignore result
            _supplyModule
        );

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(_assets);

        bytes32[] memory merkleProof = _getWithdrawMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x00000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleAccountingInstruction(address _safe, uint256 _posId, address _supplyModule)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        address[] memory positionTokens = new address[](1);
        positionTokens[0] = _supplyModule;

        bytes32[] memory commands = new bytes32[](1);
        // "0x1aefb1070200ffffffffff00" + _supplyModule
        commands[0] = _buildCommand(
            MockSupplyModule.collateralOf.selector,
            0x02, // static call
            0x00ffffffffff, // 1 input at index 0 of state
            0x00, // store fixed size result at index 0 of state
            _supplyModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_safe);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = _getAccountingMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.ACCOUNTING,
            affectedTokens,
            positionTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockBorrowModuleBorrowInstruction(uint256 _posId, address _borrowModule, uint256 _assets)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xc5ebeaec0100ffffffffffff" + _borrowModule
        commands[0] = _buildCommand(
            MockBorrowModule.borrow.selector,
            0x01, // call
            0x00ffffffffff, // 1 input at indices 0 of state
            0xff, // ignore result
            _borrowModule
        );

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(_assets);

        bytes32[] memory merkleProof = _getBorrowMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x00000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            true,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockBorrowModuleRepayInstruction(uint256 _posId, address _borrowModule, uint256 _assets)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + MockBorrowModule(_borrowModule).asset()
        commands[0] = _buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockBorrowModule(_borrowModule).asset()
        );
        // "0x371fd8e60101ffffffffffff" + _borrowModule
        commands[1] = _buildCommand(
            MockBorrowModule.repay.selector,
            0x01, // call
            0x01ffffffffff, // 1 input at indices 1 of state
            0xff, // ignore result
            _borrowModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_borrowModule);
        state[1] = abi.encode(_assets);

        bytes32[] memory merkleProof = _getRepayMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            true,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            affectedTokens,
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockBorrowModuleAccountingInstruction(address _safe, uint256 _posId, address _borrowModule)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        address[] memory positionTokens = new address[](1);
        positionTokens[0] = _borrowModule;

        bytes32[] memory commands = new bytes32[](1);
        // "0xd283e75f0200ffffffffff00" + _borrowModule
        commands[0] = _buildCommand(
            MockBorrowModule.debtOf.selector,
            0x02, // static call
            0x00ffffffffff, // 1 input at index 0 of state
            0x00, // store fixed size result at index 0 of state
            _borrowModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_safe);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = _getAccountingMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            _posId,
            true,
            0,
            IWeirollComponent.InstructionType.ACCOUNTING,
            affectedTokens,
            positionTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockRewardTokenHarvestInstruction(address _safe, address _mockRewardToken, uint256 _harvestAmount)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](1);
        // "0x40c10f19010001ffffffffff" + _mockRewardToken
        commands[0] = _buildCommand(
            MockERC20.mint.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            _mockRewardToken
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_safe);
        state[1] = abi.encode(_harvestAmount);

        bytes32[] memory merkleProof = _getHarvestMockTokenAInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return IWeirollComponent.Instruction(
            0,
            false,
            0,
            IWeirollComponent.InstructionType.HARVEST,
            new address[](0),
            new address[](0),
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildFlashLoanModuleDummyLoopInstruction(
        uint256 _posId,
        address _flashLoanModule,
        address _makinaXModule,
        address _token,
        uint256 _amount,
        IWeirollComponent.Instruction memory _manageFlashloanInstruction
    ) internal view returns (IWeirollComponent.Instruction memory) {
        bytes32[] memory commands = new bytes32[](1);
        // "0xb1485fa00180ffffffffffff" + _flashLoanModule
        commands[0] = _buildCommand(
            IFlashLoanModule.requestFlashLoan.selector,
            0x01, // call with extended flag
            0x80ffffffffff, // 1 input : variable-length at index 0 of state
            0xff, // ignore result
            _flashLoanModule
        );

        IFlashLoanModule.FlashLoanRequest memory flashLoanRequest = IFlashLoanModule.FlashLoanRequest({
            taker: address(_makinaXModule),
            provider: IFlashLoanModule.FlashLoanProvider.MORPHO,
            instruction: _manageFlashloanInstruction,
            token: _token,
            amount: _amount
        });

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(
            flashLoanRequest.taker,
            flashLoanRequest.provider,
            flashLoanRequest.instruction,
            flashLoanRequest.token,
            flashLoanRequest.amount
        );

        bytes32[] memory merkleProof = _getDummyLoopMockFlashLoanModuleInstrProof();

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.MANAGEMENT,
            new address[](0),
            new address[](0),
            commands,
            state,
            0,
            merkleProof
        );
    }

    function _buildMockFlashLoanModuleDummyAccountingInstruction(uint256 _posId)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = _getAccountingMockFlashLoanModuleInstrProof();

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.ACCOUNTING,
            new address[](0),
            new address[](0),
            new bytes32[](0),
            state,
            0,
            merkleProof
        );
    }

    function _buildManageFlashLoanDummyInstruction(uint256 _posId)
        internal
        view
        returns (IWeirollComponent.Instruction memory)
    {
        bytes32[] memory merkleProof = _getManageFlashLoanDummyInstrProof();

        return IWeirollComponent.Instruction(
            _posId,
            false,
            0,
            IWeirollComponent.InstructionType.FLASHLOAN_MANAGEMENT,
            new address[](0),
            new address[](0),
            new bytes32[](0),
            new bytes[](0),
            0,
            merkleProof
        );
    }
}

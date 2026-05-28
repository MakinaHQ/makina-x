// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";

import {Errors} from "../libraries/Errors.sol";
import {IFlashLoanModule} from "../interfaces/IFlashLoanModule.sol";
import {IMakinaLiteModule} from "../interfaces/IMakinaLiteModule.sol";
import {IModuleFactory} from "../interfaces/IModuleFactory.sol";
import {IMorpho} from "../interfaces/IMorpho.sol";
import {IMorphoFlashLoanCallback} from "../interfaces/IMorphoFlashLoanCallback.sol";
import {IWeirollComponent} from "../interfaces/IWeirollComponent.sol";

contract FlashLoanModule is IFlashLoanModule {
    using SafeERC20 for IERC20;
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("makina.storage.FlashLoanModule.expectedDataHash")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EXPECTED_DATA_HASH_SLOT =
        0x5a3c23131f48fa65e051159c96653778099b9ec7df69c3ed6471d5a36605bd00;

    /// @notice Address of the MakinaLiteModule factory.
    address public immutable moduleFactory;

    /// @notice Address of the Morpho contract.
    address public immutable morpho;

    constructor(address _moduleFactory, address _morpho) {
        if (_moduleFactory == address(0) || _morpho == address(0)) {
            revert Errors.ZeroAddress();
        }

        moduleFactory = _moduleFactory;
        morpho = _morpho;
    }

    /// @inheritdoc IFlashLoanModule
    function requestFlashLoan(FlashLoanRequest calldata request) external override {
        if (
            !IModuleFactory(moduleFactory).isMakinaLiteModule(request.taker)
                || IMakinaLiteModule(request.taker).safe() != msg.sender
        ) {
            revert Errors.InvalidFlashLoanTaker();
        }
        _dispatchFlashLoanRequest(request);
    }

    /// @inheritdoc IMorphoFlashLoanCallback
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != morpho) {
            revert Errors.NotMorpho();
        }

        _consumeExpectedDataHash(data);

        (address token, address makinaLiteModule, IWeirollComponent.Instruction memory instruction) =
            abi.decode(data, (address, address, IWeirollComponent.Instruction));

        _handleFlashLoanCallback(makinaLiteModule, instruction, token, assets);

        IERC20(token).forceApprove(morpho, assets);
    }

    /// @dev Dispatches the flash loan request to the appropriate provider.
    function _dispatchFlashLoanRequest(FlashLoanRequest calldata request) internal {
        if (request.provider == FlashLoanProvider.MORPHO) {
            _requestMorphoFlashLoan(request);
        } else {
            revert Errors.InvalidFlashLoanProvider();
        }
    }

    /// @dev Requests a flash loan from Morpho.
    function _requestMorphoFlashLoan(FlashLoanRequest calldata request) internal {
        bytes memory data = abi.encode(request.token, request.taker, request.instruction);

        _setExpectedDataHash(data);
        IMorpho(morpho).flashLoan(request.token, request.amount, data);
    }

    /// @dev Sets the expected data hash in transient storage to be used for validation in the flash loan callback.
    function _setExpectedDataHash(bytes memory data) internal {
        EXPECTED_DATA_HASH_SLOT.asBytes32().tstore(keccak256(data));
    }

    /// @dev Checks if the expected data hash matches the hash of the provided data and clears the expected data hash from transient storage.
    function _consumeExpectedDataHash(bytes memory data) internal {
        if (EXPECTED_DATA_HASH_SLOT.asBytes32().tload() != keccak256(data)) {
            revert Errors.InvalidDataHash();
        }
        EXPECTED_DATA_HASH_SLOT.asBytes32().tstore(bytes32(0));
    }

    /// @dev Delegates management of flash-loaned funds to the specified MakinaLiteModule.
    function _handleFlashLoanCallback(
        address makinaLiteModule,
        IWeirollComponent.Instruction memory instruction,
        address token,
        uint256 amount
    ) internal {
        IERC20(token).forceApprove(makinaLiteModule, amount);
        IMakinaLiteModule(makinaLiteModule).manageFlashLoan(instruction, token, amount);
    }
}

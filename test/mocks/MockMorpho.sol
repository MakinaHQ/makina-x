// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IMorphoFlashLoanCallback} from "src/interfaces/IMorphoFlashLoanCallback.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockMorpho is IMorpho {
    event FlashLoan(address token, uint256 amount, bytes data);

    bool private dummyMode;

    bool private reentrancyMode;

    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        if (dummyMode) {
            emit FlashLoan(token, amount, data);
            return;
        }

        address caller = msg.sender;
        IERC20(token).transfer(caller, amount);

        if (reentrancyMode) {
            (, address makinaXModule,) = abi.decode(data, (address, address, IWeirollComponent.Instruction));

            IWeirollComponent.Instruction memory instruction;

            MockERC20(token)
                .scheduleReenter(
                    MockERC20.Type.Before,
                    makinaXModule,
                    abi.encodeCall(IWeirollComponent.manageFlashLoan, (instruction, address(0), 0))
                );
        }

        IMorphoFlashLoanCallback(caller).onMorphoFlashLoan(amount, data);
        IERC20(token).transferFrom(caller, address(this), amount);
    }

    function setDummyMode(bool _dummyMode) external {
        dummyMode = _dummyMode;
    }

    function setReentrancyMode(bool _reentrancyMode) external {
        reentrancyMode = _reentrancyMode;
    }
}

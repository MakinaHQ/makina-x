// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IFlashLoanModule} from "src/interfaces/IFlashLoanModule.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {FlashLoanModule} from "src/flash-loans/FlashLoanModule.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract OnMorphoFlashLoan_Integration_Concrete_Test is Integration_Concrete_Test {
    bool internal indirectCall;

    function test_RevertWhen_InvalidUserDataHash() public {
        vm.expectRevert(Errors.InvalidDataHash.selector);
        flashLoanModule.onMorphoFlashLoan(0, "");
    }

    function test_RevertWhen_NotMorpho() public {
        IWeirollComponent.Instruction memory instruction;

        IFlashLoanModule.FlashLoanRequest memory request = IFlashLoanModule.FlashLoanRequest({
            taker: address(makinaLiteModule),
            provider: IFlashLoanModule.FlashLoanProvider.MORPHO,
            instruction: instruction,
            token: address(0),
            amount: 0
        });

        flashLoanModule = new FlashLoanModule(address(moduleFactory), address(this));
        indirectCall = true;

        vm.expectRevert(Errors.NotMorpho.selector);
        vm.prank(address(safe));
        flashLoanModule.requestFlashLoan(request);
    }

    function test_RevertWhen_DirectCall() public {
        IWeirollComponent.Instruction memory instruction;

        uint256 flashLoanAmount = 3e18;

        IFlashLoanModule.FlashLoanRequest memory request = IFlashLoanModule.FlashLoanRequest({
            taker: address(makinaLiteModule),
            provider: IFlashLoanModule.FlashLoanProvider.MORPHO,
            instruction: instruction,
            token: address(tokenA),
            amount: flashLoanAmount
        });

        deal(address(tokenA), address(morpho), flashLoanAmount);

        vm.expectRevert(Errors.DirectManageFlashLoanCall.selector, address(makinaLiteModule));
        vm.prank(address(safe));
        flashLoanModule.requestFlashLoan(request);
    }

    /// @dev Mocks the flashLoan function of the Morpho contract and simulates faulty behavior.
    function flashLoan(address, uint256 assets, bytes calldata data) external {
        if (indirectCall) {
            vm.prank(address(0));
        }
        flashLoanModule.onMorphoFlashLoan(assets, data);
    }
}

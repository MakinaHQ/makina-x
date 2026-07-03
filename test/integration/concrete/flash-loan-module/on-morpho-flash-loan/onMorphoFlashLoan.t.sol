// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Errors} from "src/libraries/Errors.sol";
import {IFlashLoanModule} from "src/interfaces/IFlashLoanModule.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract OnMorphoFlashLoan_Integration_Concrete_Test is Integration_Concrete_Test {
    function test_RevertWhen_NotMorpho() public {
        vm.expectRevert(Errors.NotMorpho.selector);
        flashLoanModule.onMorphoFlashLoan(0, "");
    }

    function test_RevertWhen_InvalidUserDataHash() public {
        vm.expectRevert(Errors.InvalidDataHash.selector);
        vm.prank(address(morpho));
        flashLoanModule.onMorphoFlashLoan(0, "");
    }

    function test_RevertWhen_DirectCall() public {
        IWeirollComponent.Instruction memory instruction;

        uint256 flashLoanAmount = 3e18;

        IFlashLoanModule.FlashLoanRequest memory request = IFlashLoanModule.FlashLoanRequest({
            taker: address(makinaXModule),
            provider: IFlashLoanModule.FlashLoanProvider.MORPHO,
            instruction: instruction,
            token: address(tokenA),
            amount: flashLoanAmount
        });

        deal(address(tokenA), address(morpho), flashLoanAmount);

        vm.expectRevert(Errors.DirectManageFlashLoanCall.selector, address(makinaXModule));
        vm.prank(address(safe));
        flashLoanModule.requestFlashLoan(request);
    }

    /// @dev Mocks the flashLoan function of the Morpho contract and simulates faulty behavior.
    function flashLoan(address, uint256 assets, bytes calldata data) external {
        flashLoanModule.onMorphoFlashLoan(assets, data);
    }
}

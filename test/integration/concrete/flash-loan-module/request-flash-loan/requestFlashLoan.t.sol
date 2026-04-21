// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "src/libraries/Errors.sol";
import {IFlashLoanModule} from "src/interfaces/IFlashLoanModule.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {MockMorpho} from "test/mocks/MockMorpho.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract RequestFlashLoan_Integration_Concrete_Test is Integration_Concrete_Test {
    function test_RevertWhen_InvalidFlashLoanTaker() public {
        IFlashLoanModule.FlashLoanRequest memory request;

        vm.expectRevert(Errors.InvalidFlashLoanTaker.selector);
        flashLoanModule.requestFlashLoan(request);

        request.taker = address(makinaLiteModule);

        vm.expectRevert(Errors.InvalidFlashLoanTaker.selector);
        flashLoanModule.requestFlashLoan(request);
    }

    function test_RevertWhen_InvalidFlashLoanProvider() public {
        IWeirollComponent.Instruction memory instruction;

        IFlashLoanModule.FlashLoanRequest memory request = IFlashLoanModule.FlashLoanRequest({
            taker: address(makinaLiteModule),
            provider: IFlashLoanModule.FlashLoanProvider(0),
            instruction: instruction,
            token: address(0),
            amount: 0
        });

        vm.expectRevert(Errors.InvalidFlashLoanProvider.selector);
        vm.prank(address(safe));
        flashLoanModule.requestFlashLoan(request);
    }

    function test_Morpho() public {
        IWeirollComponent.Instruction memory instruction;
        address token = makeAddr("token");
        uint256 amount = 3e18;

        IFlashLoanModule.FlashLoanRequest memory request = IFlashLoanModule.FlashLoanRequest({
            taker: address(makinaLiteModule),
            provider: IFlashLoanModule.FlashLoanProvider.MORPHO,
            instruction: instruction,
            token: token,
            amount: amount
        });

        morpho.setDummyMode(true);

        vm.expectEmit(false, false, false, true, address(morpho));
        emit MockMorpho.FlashLoan(token, amount, abi.encode(token, address(makinaLiteModule), instruction));

        vm.prank(address(safe));
        flashLoanModule.requestFlashLoan(request);
    }
}

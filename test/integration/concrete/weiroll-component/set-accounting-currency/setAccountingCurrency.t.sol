// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ISwapComponent} from "src/interfaces/ISwapComponent.sol";
import {IWeirollComponent} from "src/interfaces/IWeirollComponent.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockDex} from "test/mocks/MockDex.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {WeirollComponent_Integration_Concrete_Test} from "../WeirollComponent.t.sol";

contract SetAccountingCurrency_Integration_Concrete_Test is WeirollComponent_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1;
        deal(address(tokenA), address(safe), inputAmount, true);
        deal(address(tokenB), address(dex), 1e20, true);

        ISwapComponent.SwapOrder memory order = ISwapComponent.SwapOrder({
            swapperId: TEST_SWAPPER_ID,
            data: abi.encodeCall(MockDex.swap, (address(tokenA), address(tokenB), inputAmount)),
            inputToken: address(tokenA),
            outputToken: address(tokenB),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        tokenA.scheduleReenter(
            MockERC20.Type.Before,
            address(makinaXModule),
            abi.encodeCall(IWeirollComponent.setAccountingCurrency, (address(0)))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.swap(order);
    }

    function test_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.setAccountingCurrency(address(0));
    }

    function test_RevertGiven_FeedRouteNotRegistered() public {
        address newToken = makeAddr("newToken");
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, newToken));
        vm.prank(address(safe));
        makinaXModule.setAccountingCurrency(newToken);
    }

    function test_SetAccountingCurrency() public {
        vm.expectEmit(true, true, false, false, address(makinaXModule));
        emit IWeirollComponent.AccountingCurrencyChanged(address(0), address(tokenA));
        vm.prank(address(safe));
        makinaXModule.setAccountingCurrency(address(tokenA));

        assertEq(makinaXModule.accountingCurrency(), address(tokenA));
    }
}

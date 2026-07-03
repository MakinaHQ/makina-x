// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {ISwapComponent} from "src/interfaces/ISwapComponent.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockDex} from "test/mocks/MockDex.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract SetFeedRoute_Integration_Concrete_Test is Integration_Concrete_Test {
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
            abi.encodeCall(IOracleRegistry.setFeedRoute, (address(0), address(0), 0, address(0), 0))
        );

        vm.expectRevert();
        vm.prank(operator);
        makinaXModule.swap(order);
    }
}

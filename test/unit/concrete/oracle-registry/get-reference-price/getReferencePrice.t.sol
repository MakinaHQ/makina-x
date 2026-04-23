// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract GetReferencePrice_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    /// @dev A is the base token, C is an intermediate token
    /// and E is the reference currency of the oracle registry
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_A_C = 50;
    uint256 internal constant PRICE_C_E = 3;

    MockPriceFeed internal basePriceFeed1;
    MockPriceFeed internal basePriceFeed2;

    function test_RevertGiven_BaseTokenFeedRouteNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken)));
        oracleRegistry.getReferencePrice(address(baseToken));
    }

    function test_RevertGiven_NegativePrice_1() public {
        basePriceFeed1 = new MockPriceFeed(18, -1e18, block.timestamp);

        vm.prank(address(safe));
        oracleRegistry.setFeedRoute(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NegativeTokenPrice.selector, address(basePriceFeed1)));
        oracleRegistry.getReferencePrice(address(baseToken));
    }

    function test_RevertGiven_NegativePrice_2() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, -1e18, block.timestamp);

        vm.prank(address(safe));
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NegativeTokenPrice.selector, address(basePriceFeed2)));
        oracleRegistry.getReferencePrice(address(baseToken));
    }

    function test_RevertGiven_StalePrice_1() public {
        uint256 startTimestamp = block.timestamp;
        basePriceFeed1 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD);

        vm.prank(address(safe));
        oracleRegistry.setFeedRoute(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedStale.selector, address(basePriceFeed1), startTimestamp));
        oracleRegistry.getReferencePrice(address(baseToken));
    }

    function test_RevertGiven_StalePrice_2() public {
        uint256 startTimestamp = vm.getBlockNumber();
        basePriceFeed2 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD);

        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.prank(address(safe));
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedStale.selector, address(basePriceFeed2), startTimestamp));
        oracleRegistry.getReferencePrice(address(baseToken));
    }

    function test_GetReferencePrice_A() public {
        basePriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_C * (10 ** 18)), block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, int256(PRICE_C_E * (10 ** 18)), block.timestamp);

        vm.prank(address(safe));
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        uint256 price = oracleRegistry.getReferencePrice(address(baseToken));
        assertEq(price, PRICE_A_E * (10 ** DecimalsUtils.REFERENCE_CURRENCY_DECIMALS));
    }
}

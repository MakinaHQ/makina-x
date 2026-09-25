// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract ClearFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    MockPriceFeed internal priceFeed1;
    MockPriceFeed internal priceFeed2;

    function test_RevertWhen_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        oracleRegistry.clearFeedRoute(address(0));
    }

    function test_RevertWhen_FeedRouteNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(0)));
        vm.prank(address(safe));
        oracleRegistry.clearFeedRoute(address(0));
    }

    function test_ClearFeedRoute_With1Feed() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.startPrank(address(safe));
        oracleRegistry.setFeedRoute(address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        vm.expectEmit(true, false, false, false, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteCleared(address(baseToken));
        oracleRegistry.clearFeedRoute(address(baseToken));

        vm.stopPrank();

        assertFalse(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);
    }

    function test_ClearFeedRoute_With2Feeds() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        priceFeed2 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.startPrank(address(safe));

        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(priceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(priceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        vm.expectEmit(true, false, false, false, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteCleared(address(baseToken));
        oracleRegistry.clearFeedRoute(address(baseToken));

        vm.stopPrank();

        assertFalse(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed2)), DEFAULT_PF_STALE_THRSHLD);
    }
}

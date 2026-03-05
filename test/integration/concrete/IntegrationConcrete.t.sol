// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {MakinaLiteModule} from "src/MakinaLiteModule.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockDex} from "test/mocks/MockDex.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "../../base/Base.t.sol";

abstract contract Integration_Concrete_Test is Base_Test {
    /// @dev A denotes tokenA, B denotes tokenB
    /// and E is the reference currency of the oracle registry.
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_B_E = 60000;
    uint256 internal constant PRICE_B_A = 400;

    MockERC20 public tokenA;
    MockERC20 public tokenB;

    MockPriceFeed internal aPriceFeed1;
    MockPriceFeed internal bPriceFeed1;

    MockDex internal dex;

    MakinaLiteModule internal makinaLiteModule;

    function setUp() public virtual override {
        Base_Test.setUp();

        tokenA = new MockERC20("tokenA", "TA", 18);
        tokenB = new MockERC20("tokenB", "TB", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        dex = new MockDex();
        dex.setQuote(address(tokenA), address(tokenB), 1, PRICE_B_A);

        makinaLiteModule = new MakinaLiteModule(
            address(registry), address(safe), dao, DEFAULT_MAX_SWAP_LOSS_BPS, DEFAULT_SWAP_FEE_RATE
        );

        vm.startPrank(address(safe));

        makinaLiteModule.addOperator(operator);
        makinaLiteModule.addGuardian(guardian);

        makinaLiteModule.setFeedRoute(
            address(tokenA), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        makinaLiteModule.setFeedRoute(
            address(tokenB), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        makinaLiteModule.setSwapperTargets(TEST_SWAPPER_ID, address(dex), address(dex));

        vm.stopPrank();
    }

    modifier whileInLockdownMode() {
        vm.startPrank(address(safe));
        makinaLiteModule.setLockdownMode(true);
        vm.stopPrank();
        _;
    }
}

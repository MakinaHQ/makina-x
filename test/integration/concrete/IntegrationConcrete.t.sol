// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IMakinaXGovernable} from "src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {MakinaXModule} from "src/MakinaXModule.sol";
import {MockBorrowModule} from "test/mocks/MockBorrowModule.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MockDex} from "test/mocks/MockDex.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockSupplyModule} from "test/mocks/MockSupplyModule.sol";
import {VMInstructionHelper} from "test/utils/VMInstructionHelper.sol";

import {Base_Test} from "../../base/Base.t.sol";

abstract contract Integration_Concrete_Test is Base_Test, VMInstructionHelper {
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

    MockERC4626 internal vault;
    MockSupplyModule internal supplyModule;
    MockBorrowModule internal borrowModule;

    MakinaXModule internal makinaXModule;

    function setUp() public virtual override {
        Base_Test.setUp();

        tokenA = new MockERC20("tokenA", "TA", 18);
        tokenB = new MockERC20("tokenB", "TB", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        dex = new MockDex();
        dex.setQuote(address(tokenA), address(tokenB), 1, PRICE_B_A);

        vault = new MockERC4626("vault", "VLT", IERC20(tokenB), 0);
        supplyModule = new MockSupplyModule(IERC20(tokenB));
        borrowModule = new MockBorrowModule(IERC20(tokenB));

        vm.prank(dao);
        makinaXModule = MakinaXModule(
            payable(moduleFactory.createModule(
                    IMakinaXModule.MakinaXModuleInitParams({
                        safe: address(safe),
                        initialOperatingMode: IMakinaXGovernable.OperatingMode.OPEN,
                        initialAllowedInstrRoot: bytes32(0),
                        initialMaxPositionIncreaseLossBps: DEFAULT_MAX_POS_INCREASE_LOSS_BPS,
                        initialMaxPositionDecreaseLossBps: DEFAULT_MAX_POS_DECREASE_LOSS_BPS,
                        initialInstrCooldownDuration: DEFAULT_INSTR_COOLDOWN_DURATION,
                        initialMaxSwapLossBps: DEFAULT_MAX_SWAP_LOSS_BPS,
                        initialSwapCooldownDuration: DEFAULT_SWAP_COOLDOWN_DURATION
                    }),
                    IMakinaXModule.MakinaXModuleServiceParams({
                        initialProvider: dao, initialSwapFeeRate: DEFAULT_SWAP_FEE_RATE
                    }),
                    TEST_DEPLOYMENT_SALT,
                    0
                ))
        );

        vm.startPrank(address(safe));

        makinaXModule.addOperator(operator);
        makinaXModule.addGuardian(guardian);

        makinaXModule.setFeedRoute(address(tokenA), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        makinaXModule.setFeedRoute(address(tokenB), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        makinaXModule.setSwapperTargets(TEST_SWAPPER_ID, address(dex), address(dex));

        vm.stopPrank();
    }

    modifier whileInFencedMode() {
        vm.prank(address(safe));
        makinaXModule.setOperatingMode(IMakinaXGovernable.OperatingMode.FENCED);
        _;
    }

    modifier whileInWalledMode() {
        vm.prank(address(safe));
        makinaXModule.setOperatingMode(IMakinaXGovernable.OperatingMode.WALLED);
        _;
    }

    modifier withAccountingCurrency(address currency) {
        vm.prank(address(safe));
        makinaXModule.setAccountingCurrency(currency);
        _;
    }
}

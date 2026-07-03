// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXGovernable} from "src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {MakinaXModule} from "src/MakinaXModule.sol";

import {Base_Test} from "../../base/Base.t.sol";

abstract contract Unit_Concrete_Test is Base_Test {
    MakinaXModule internal makinaXModule;

    function setUp() public virtual override {
        Base_Test.setUp();

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
    }
}

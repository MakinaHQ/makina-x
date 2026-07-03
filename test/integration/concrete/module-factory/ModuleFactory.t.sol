// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXGovernable} from "src/interfaces/IMakinaXGovernable.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract ModuleFactory_Integration_Concrete_Test is Integration_Concrete_Test {
    function _defaultInitParams(address _safe) internal view returns (IMakinaXModule.MakinaXModuleInitParams memory) {
        return IMakinaXModule.MakinaXModuleInitParams({
            safe: _safe,
            initialOperatingMode: IMakinaXGovernable.OperatingMode.OPEN,
            initialAllowedInstrRoot: bytes32(0),
            initialMaxPositionIncreaseLossBps: DEFAULT_MAX_POS_INCREASE_LOSS_BPS,
            initialMaxPositionDecreaseLossBps: DEFAULT_MAX_POS_DECREASE_LOSS_BPS,
            initialInstrCooldownDuration: DEFAULT_INSTR_COOLDOWN_DURATION,
            initialMaxSwapLossBps: DEFAULT_MAX_SWAP_LOSS_BPS,
            initialSwapCooldownDuration: DEFAULT_SWAP_COOLDOWN_DURATION
        });
    }
}

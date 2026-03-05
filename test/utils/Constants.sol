// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

abstract contract Constants {
    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    uint256 internal constant DEFAULT_MAX_SWAP_LOSS_BPS = 200;
    uint256 internal constant DEFAULT_SWAP_FEE_RATE = 1e15; // 0.1%

    uint16 public constant TEST_SWAPPER_ID = 100;
}

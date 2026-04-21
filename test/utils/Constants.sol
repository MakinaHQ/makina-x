// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

abstract contract Constants {
    bytes32 public constant TEST_DEPLOYMENT_SALT = keccak256("makina.salt.test");

    uint32 internal constant L2_CHAIN_ID = 8453;

    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    uint256 internal constant DEFAULT_MAX_POS_INCREASE_LOSS_BPS = 100;
    uint256 internal constant DEFAULT_MAX_POS_DECREASE_LOSS_BPS = 1000;
    uint256 internal constant DEFAULT_MAX_SWAP_LOSS_BPS = 200;
    uint256 internal constant DEFAULT_SWAP_FEE_RATE = 1e15; // 0.1%
    uint256 internal constant DEFAULT_MAX_BRIDGE_LOSS_BPS = 300;

    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant SUPPLY_POS_ID = 4;
    uint256 internal constant BORROW_POS_ID = 5;
    uint256 internal constant LOOP_POS_ID = 6;

    uint32 internal constant ACROSS_V4_FILL_DEADLINE_OFFSET = 1 hours;

    uint32 internal constant LAYER_ZERO_V2_L2_CHAIN_ID = 30184;
    uint128 internal constant DEFAULT_LAYER_ZERO_V2_LZ_VERIFY_GAS = 80000;
    uint128 internal constant DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS = 150000;
    uint256 internal constant DEFAULT_LAYER_ZERO_V2_GAS_PRICE = 1e9;

    uint32 internal constant CCTP_V2_SPOKE_DOMAIN = 6;
    uint256 internal constant CCTP_V2_FEE_MILLI_BPS = 1000;
    uint32 internal constant CCTP_V2_CONFIRMED_FINALITY_THRESHOLD = 1000;

    uint16 public constant TEST_SWAPPER_ID = 100;

    uint16 public constant DUMMY_BRIDGE_ID = 100;
}

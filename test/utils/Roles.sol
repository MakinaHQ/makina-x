// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

library Roles {
    uint64 public constant INFRA_CONFIG_ROLE = 1;
    uint64 public constant STRATEGY_DEPLOYMENT_ROLE = 2;
    uint64 public constant INFRA_UPGRADE_ROLE = 6;
    uint64 public constant GUARDIAN_ROLE = 7;
}

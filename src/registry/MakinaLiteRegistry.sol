// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IMakinaLiteRegistry} from "../interfaces/IMakinaLiteRegistry.sol";

contract MakinaLiteRegistry is AccessManagedUpgradeable, IMakinaLiteRegistry {
    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }
}

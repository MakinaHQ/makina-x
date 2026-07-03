// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {IMakinaXContext} from "../interfaces/IMakinaXContext.sol";

abstract contract MakinaXContext is IMakinaXContext {
    /// @inheritdoc IMakinaXContext
    address public immutable override registry;

    constructor(address _registry) {
        registry = _registry;
    }
}

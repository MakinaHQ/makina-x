// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IMakinaLiteContext} from "../interfaces/IMakinaLiteContext.sol";

abstract contract MakinaLiteContext is IMakinaLiteContext {
    /// @inheritdoc IMakinaLiteContext
    address public immutable override registry;

    constructor(address _registry) {
        registry = _registry;
    }
}

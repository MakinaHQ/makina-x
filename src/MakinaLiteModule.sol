// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IMakinaLiteModule} from "./interfaces/IMakinaLiteModule.sol";
import {MakinaLiteContext} from "./utils/MakinaLiteContext.sol";
import {MakinaLiteGovernable} from "./utils/MakinaLiteGovernable.sol";
import {OracleRegistry, IOracleRegistry} from "./module-components/OracleRegistry.sol";

contract MakinaLiteModule is MakinaLiteContext, MakinaLiteGovernable, OracleRegistry, IMakinaLiteModule {
    constructor(address registry, address _safe, address _provider)
        MakinaLiteContext(registry)
        MakinaLiteGovernable(_safe, _provider)
    {}

    /// @inheritdoc IOracleRegistry
    function setFeedRoute(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external override onlySafe {
        _setFeedRoute(token, feed1, stalenessThreshold1, feed2, stalenessThreshold2);
    }

    /// @inheritdoc IOracleRegistry
    function clearFeedRoute(address token) external override onlySafe {
        _clearFeedRoute(token);
    }

    /// @inheritdoc IOracleRegistry
    function setFeedStaleThreshold(address feed, uint256 newThreshold) external onlySafe {
        _setFeedStaleThreshold(feed, newThreshold);
    }
}

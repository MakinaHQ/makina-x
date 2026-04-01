// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBridgeComponent} from "./IBridgeComponent.sol";
import {IOracleRegistry} from "./IOracleRegistry.sol";
import {ISwapComponent} from "./ISwapComponent.sol";
import {IWeirollComponent} from "./IWeirollComponent.sol";

interface IMakinaLiteModule is IOracleRegistry, IWeirollComponent, ISwapComponent, IBridgeComponent {
    /// @notice Sweeps the entire balance of a given ERC20 token to the caller.
    /// @param token The address of the ERC20 token to sweep.
    function sweepERC20(address token) external;

    /// @notice Sweeps the entire native currency balance (e.g. ETH) to the caller.
    function sweepNative() external;
}

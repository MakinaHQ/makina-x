// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IMakinaLiteRegistry {
    event FeeCollectorChanged(address indexed oldFeeCollector, address indexed newFeeCollector);

    /// @notice Address of the fee collector.
    function feeCollector() external view returns (address);

    /// @notice Sets the address of the fee collector.
    /// @param newFeeCollector The address of the new fee collector.
    function setFeeCollector(address newFeeCollector) external;
}

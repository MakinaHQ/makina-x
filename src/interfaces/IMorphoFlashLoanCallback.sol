// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

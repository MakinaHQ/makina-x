// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBridgeEncoder} from "./IBridgeEncoder.sol";

interface ILayerZeroV2BridgeEncoder is IBridgeEncoder {
    event LzEndpointIdRegistered(uint256 indexed evmChainId, uint32 indexed lzEndpointId);
    event OftAdded(address indexed oft);
    event OftRemoved(address indexed oft);

    /// @notice EVM chain ID => LayerZero endpoint ID
    function getLzEndpointId(uint256 evmChainId) external view returns (uint32);

    /// @notice OFT => Whether the OFT is registered
    function isOftRegistered(address oft) external view returns (bool);

    /// @notice Associates an EVM chain ID with a LayerZero endpoint ID in the contract storage.
    /// @param evmChainId The EVM chain ID.
    /// @param lzEndpointId The LayerZero endpoint ID.
    function setLzEndpointId(uint256 evmChainId, uint32 lzEndpointId) external;

    /// @notice Registers an OFT contract.
    /// @param oft The address of the OFT.
    function addOft(address oft) external;

    /// @notice Unregisters an OFT contract.
    /// @param oft The address of the OFT.
    function removeOft(address oft) external;
}

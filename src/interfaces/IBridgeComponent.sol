// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBridgeComponent {
    event BridgeTransferRecipientAdded(uint256 indexed foreignChainId, address indexed recipient);
    event BridgeTransferRecipientRemoved(uint256 indexed foreignChainId, address indexed recipient);
    event BridgeCooldownDurationChanged(uint256 oldBridgeCooldownDuration, uint256 newBridgeCooldownDuration);
    event MaxBridgeLossBpsChanged(
        uint16 indexed bridgeId, uint256 indexed oldMaxBridgeLossBps, uint256 indexed newMaxBridgeLossBps
    );

    /// @notice Generic bridge transfer params.
    /// @param bridgeId The ID of the bridge.
    /// @param destinationChainId The destination EVM chain ID.
    /// @param recipient The address of the recipient.
    /// @param inputToken The address of the input token.
    /// @param inputAmount The amount of input token to bridge.
    /// @param minOutputAmount The minimum amount of output token expected.
    /// @param extraData Extra data specific to each bridge integration.
    struct BridgeOrder {
        uint16 bridgeId;
        uint256 destinationChainId;
        address recipient;
        address inputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
        bytes extraData;
    }

    /// @notice Bridge ID => Max allowed value loss in basis points for transfers via this bridge while in FENCED or WALLED mode.
    function getMaxBridgeLossBps(uint16 bridgeId) external view returns (uint256);

    /// @notice Foreign Chain ID => Recipient => Whitelisting status while in FENCED or WALLED mode.
    function isWhitelistedRecipient(uint256 foreignChainId, address recipient) external view returns (bool);

    /// @notice Cooldown duration (in seconds) for bridge transfers while in FENCED or WALLED mode.
    function bridgeCooldownDuration() external view returns (uint256);

    /// @notice Executes an outgoing bridge transfer.
    /// @param order The bridge transfer params.
    function sendOutBridgeTransfer(BridgeOrder calldata order) external;

    /// @notice Sets the maximum allowed relative value loss for transfers via this bridge while in FENCED or WALLED mode.
    /// @param bridgeId The ID of the bridge.
    /// @param newMaxBridgeLossBps The new maximum value loss in basis points.
    function setMaxBridgeLossBps(uint16 bridgeId, uint256 newMaxBridgeLossBps) external;

    /// @notice Sets the cooldown duration for bridge transfers while in FENCED or WALLED mode.
    /// @param newBridgeCooldownDuration The new cooldown duration in seconds.
    function setBridgeCooldownDuration(uint256 newBridgeCooldownDuration) external;

    /// @notice Adds a whitelisted recipient for bridge transfer to a given foreign chain while in FENCED or WALLED mode.
    /// @param foreignChainId The foreign chain ID.
    /// @param recipient The address of the recipient.
    function addRecipient(uint256 foreignChainId, address recipient) external;

    /// @notice Removes a whitelisted recipient for bridge transfer to a given foreign chain while in FENCED or WALLED mode.
    /// @param foreignChainId The foreign chain ID.
    /// @param recipient The address of the recipient.
    function removeRecipient(uint256 foreignChainId, address recipient) external;
}

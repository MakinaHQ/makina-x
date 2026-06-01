// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeComponent} from "../interfaces/IBridgeComponent.sol";
import {IBridgeEncoder} from "../interfaces/IBridgeEncoder.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract BridgeComponent is IBridgeComponent {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    mapping(uint16 bridgeId => uint256 maxBridgeLossBps) private _maxBridgeLossBps;
    mapping(uint256 foreignChainId => mapping(address recipient => bool isWhitelisted)) private _isWhitelistedRecipient;
    mapping(uint16 bridgeId => uint256 timestamp) private _lastGuardedBridgeOutTimestamp;

    /// @inheritdoc IBridgeComponent
    uint256 public bridgeCooldownDuration;

    /// @inheritdoc IBridgeComponent
    function getMaxBridgeLossBps(uint16 bridgeId) external view returns (uint256) {
        return _maxBridgeLossBps[bridgeId];
    }

    /// @inheritdoc IBridgeComponent
    function isWhitelistedRecipient(uint256 foreignChainId, address recipient) external view returns (bool) {
        return _isWhitelistedRecipient[foreignChainId][recipient];
    }

    function _sendOutBridgeTransfer(IBridgeComponent.BridgeOrder calldata order, address encoder, bool guarded)
        internal
    {
        if (guarded) {
            _checkAndSetCooldown(order.bridgeId);

            if (!_isWhitelistedRecipient[order.destinationChainId][order.recipient]) {
                revert Errors.RecipientNotWhitelisted();
            }

            if (
                order.minOutputAmount
                    < order.inputAmount.mulDiv(MAX_BPS - _maxBridgeLossBps[order.bridgeId], MAX_BPS, Math.Rounding.Ceil)
            ) {
                revert Errors.MaxValueLossExceeded();
            }
        }

        (address approvalTarget, address executionTarget, uint256 value, bytes memory cd) =
            IBridgeEncoder(encoder).getBridgeTransferData(order);

        if (approvalTarget != address(0)) {
            IERC20(order.inputToken).forceApprove(approvalTarget, order.inputAmount);
        }

        // Requires `address(this).balance >= value` when `value` > 0.
        Address.functionCallWithValue(executionTarget, cd, value);

        if (approvalTarget != address(0)) {
            IERC20(order.inputToken).forceApprove(approvalTarget, 0);
        }
    }

    /// @dev Internal logic to set the maximum allowed relative value loss for transfers via a given bridge.
    function _setMaxBridgeLossBps(uint16 bridgeId, uint256 newMaxBridgeLossBps) internal {
        emit MaxBridgeLossBpsChanged(bridgeId, _maxBridgeLossBps[bridgeId], newMaxBridgeLossBps);
        _maxBridgeLossBps[bridgeId] = newMaxBridgeLossBps;
    }

    /// @dev Internal logic to set the cooldown duration for bridge transfers.
    function _setBridgeCooldownDuration(uint256 newBridgeCooldownDuration) internal {
        emit BridgeCooldownDurationChanged(bridgeCooldownDuration, newBridgeCooldownDuration);
        bridgeCooldownDuration = newBridgeCooldownDuration;
    }

    /// @dev Internal logic to add a whitelisted recipient for bridge transfer towards given foreign chain.
    function _addRecipient(uint256 foreignChainId, address recipient) internal {
        if (_isWhitelistedRecipient[foreignChainId][recipient]) {
            revert Errors.RecipientAlreadyWhitelisted();
        }
        _isWhitelistedRecipient[foreignChainId][recipient] = true;
        emit BridgeTransferRecipientAdded(foreignChainId, recipient);
    }

    /// @dev Internal logic to remove a whitelisted recipient for bridge transfer towards given foreign chain.
    function _removeRecipient(uint256 foreignChainId, address recipient) internal {
        if (!_isWhitelistedRecipient[foreignChainId][recipient]) {
            revert Errors.RecipientNotWhitelisted();
        }
        _isWhitelistedRecipient[foreignChainId][recipient] = false;
        emit BridgeTransferRecipientRemoved(foreignChainId, recipient);
    }

    /// @dev Checks cooldown for a given bridge and updates its last guarded outgoing transfer timestamp.
    function _checkAndSetCooldown(uint16 bridgeId) internal {
        uint256 timestamp = block.timestamp;
        if (
            _lastGuardedBridgeOutTimestamp[bridgeId] != 0
                && timestamp - _lastGuardedBridgeOutTimestamp[bridgeId] < bridgeCooldownDuration
        ) {
            revert Errors.OngoingCooldown();
        }
        _lastGuardedBridgeOutTimestamp[bridgeId] = timestamp;
    }
}

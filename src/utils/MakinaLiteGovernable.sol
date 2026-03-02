// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Errors} from "../libraries/Errors.sol";
import {IMakinaLiteGovernable} from "../interfaces/IMakinaLiteGovernable.sol";

abstract contract MakinaLiteGovernable is IMakinaLiteGovernable {
    /// @inheritdoc IMakinaLiteGovernable
    address public immutable override safe;

    /// @inheritdoc IMakinaLiteGovernable
    address public provider;

    /// @inheritdoc IMakinaLiteGovernable
    mapping(address account => bool isOperator) public isOperator;

    /// @inheritdoc IMakinaLiteGovernable
    mapping(address account => bool isGuardian) public isGuardian;

    /// @inheritdoc IMakinaLiteGovernable
    bool public paused;

    /// @inheritdoc IMakinaLiteGovernable
    bool public suspendedByProvider;

    /// @inheritdoc IMakinaLiteGovernable
    bool public lockdownMode;

    constructor(address _safe, address _provider) {
        safe = _safe;
        isGuardian[_safe] = true;
        provider = _provider;
    }

    modifier onlySafe() {
        if (msg.sender != safe) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlyProvider() {
        if (msg.sender != provider) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlyGuardian() {
        if (!isGuardian[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier whenOperational() {
        if (suspendedByProvider) {
            revert Errors.Suspended();
        }
        if (paused) {
            revert Errors.Paused();
        }
        _;
    }

    /// @inheritdoc IMakinaLiteGovernable
    function setProvider(address newProvider) external override onlyProvider {
        if (newProvider == provider) {
            return;
        }
        emit ProviderChanged(provider, newProvider);
        provider = newProvider;
    }

    /// @inheritdoc IMakinaLiteGovernable
    function addOperator(address newOperator) external override onlySafe {
        if (isOperator[newOperator]) {
            revert Errors.AlreadyOperator();
        }
        isOperator[newOperator] = true;
        emit OperatorAdded(newOperator);
    }

    /// @inheritdoc IMakinaLiteGovernable
    function removeOperator(address operator) external override onlySafe {
        if (!isOperator[operator]) {
            revert Errors.NotOperator();
        }
        isOperator[operator] = false;
        emit OperatorRemoved(operator);
    }

    /// @inheritdoc IMakinaLiteGovernable
    function addGuardian(address newGuardian) external override onlySafe {
        if (isGuardian[newGuardian]) {
            revert Errors.AlreadyGuardian();
        }
        isGuardian[newGuardian] = true;
        emit GuardianAdded(newGuardian);
    }

    /// @inheritdoc IMakinaLiteGovernable
    function removeGuardian(address guardian) external override onlySafe {
        if (guardian == safe) {
            revert Errors.ProtectedGuardian();
        }
        if (!isGuardian[guardian]) {
            revert Errors.NotGuardian();
        }
        isGuardian[guardian] = false;
        emit GuardianRemoved(guardian);
    }

    /// @inheritdoc IMakinaLiteGovernable
    function setLockdownMode(bool enabled) external onlySafe {
        if (lockdownMode != enabled) {
            emit LockdownModeChanged(enabled);
            lockdownMode = enabled;
        }
    }

    /// @inheritdoc IMakinaLiteGovernable
    function suspend() external onlyProvider {
        if (!suspendedByProvider) {
            emit Suspended();
            suspendedByProvider = true;
        }
    }

    /// @inheritdoc IMakinaLiteGovernable
    function unsuspend() external onlyProvider {
        if (suspendedByProvider) {
            emit Unsuspended();
            suspendedByProvider = false;
        }
    }

    /// @inheritdoc IMakinaLiteGovernable
    function pause() external onlyGuardian {
        if (!paused) {
            emit Paused(msg.sender);
            paused = true;
        }
    }

    /// @inheritdoc IMakinaLiteGovernable
    function unpause() external onlyGuardian {
        if (paused) {
            emit Unpaused(msg.sender);
            paused = false;
        }
    }
}

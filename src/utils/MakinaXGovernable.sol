// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "../libraries/Errors.sol";
import {IMakinaXGovernable} from "../interfaces/IMakinaXGovernable.sol";

abstract contract MakinaXGovernable is Initializable, IMakinaXGovernable {
    /// @inheritdoc IMakinaXGovernable
    address public override safe;

    /// @inheritdoc IMakinaXGovernable
    address public override provider;

    /// @inheritdoc IMakinaXGovernable
    mapping(address account => bool isOperator) public override isOperator;

    /// @inheritdoc IMakinaXGovernable
    mapping(address account => bool isGuardian) public override isGuardian;

    /// @inheritdoc IMakinaXGovernable
    bool public override paused;

    /// @inheritdoc IMakinaXGovernable
    bool public override suspendedByProvider;

    /// @inheritdoc IMakinaXGovernable
    OperatingMode public override operatingMode;

    function __MakinaXGovernable_init(address _safe, address _provider, OperatingMode _initialOperatingMode)
        internal
        onlyInitializing
    {
        if (_safe == address(0)) {
            revert Errors.ZeroAddress();
        }
        safe = _safe;
        _addGuardian(_safe);
        _setProvider(_provider);
        _setOperatingMode(_initialOperatingMode);
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

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) {
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

    /// @inheritdoc IMakinaXGovernable
    function setProvider(address newProvider) external override onlyProvider {
        if (newProvider != provider) {
            _setProvider(newProvider);
        }
    }

    /// @inheritdoc IMakinaXGovernable
    function addOperator(address newOperator) external override onlySafe {
        if (isOperator[newOperator]) {
            revert Errors.AlreadyOperator();
        }
        isOperator[newOperator] = true;
        emit OperatorAdded(newOperator);
    }

    /// @inheritdoc IMakinaXGovernable
    function removeOperator(address operator) external override onlySafe {
        if (!isOperator[operator]) {
            revert Errors.NotOperator();
        }
        isOperator[operator] = false;
        emit OperatorRemoved(operator);
    }

    /// @inheritdoc IMakinaXGovernable
    function addGuardian(address newGuardian) external override onlySafe {
        if (isGuardian[newGuardian]) {
            revert Errors.AlreadyGuardian();
        }
        _addGuardian(newGuardian);
    }

    /// @inheritdoc IMakinaXGovernable
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

    /// @inheritdoc IMakinaXGovernable
    function setOperatingMode(OperatingMode newMode) external override onlySafe {
        _setOperatingMode(newMode);
    }

    /// @inheritdoc IMakinaXGovernable
    function suspend() external override onlyProvider {
        if (!suspendedByProvider) {
            emit Suspended();
            suspendedByProvider = true;
        }
    }

    /// @inheritdoc IMakinaXGovernable
    function unsuspend() external override onlyProvider {
        if (suspendedByProvider) {
            emit Unsuspended();
            suspendedByProvider = false;
        }
    }

    /// @inheritdoc IMakinaXGovernable
    function pause() external override onlyGuardian {
        if (!paused) {
            emit Paused(msg.sender);
            paused = true;
        }
    }

    /// @inheritdoc IMakinaXGovernable
    function unpause() external override onlyGuardian {
        if (paused) {
            emit Unpaused(msg.sender);
            paused = false;
        }
    }

    /// @dev Internal function to update the MakinaX service account.
    function _setProvider(address newProvider) internal {
        emit ProviderChanged(provider, newProvider);
        provider = newProvider;
    }

    /// @dev Internal logic to add a new guardian.
    function _addGuardian(address newGuardian) internal {
        isGuardian[newGuardian] = true;
        emit GuardianAdded(newGuardian);
    }

    /// @dev Internal logic to update the operating mode.
    function _setOperatingMode(OperatingMode newMode) internal {
        emit OperatingModeChanged(newMode);
        operatingMode = newMode;
    }
}

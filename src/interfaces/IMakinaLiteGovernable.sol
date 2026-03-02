// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IMakinaLiteGovernable {
    event GuardianAdded(address indexed newGuardian);
    event GuardianRemoved(address indexed guardian);
    event LockdownModeChanged(bool indexed enabled);
    event OperatorAdded(address indexed newOperator);
    event OperatorRemoved(address indexed operator);
    event Paused(address indexed guardian);
    event Unpaused(address indexed guardian);
    event ProviderChanged(address indexed oldProvider, address indexed newProvider);
    event Suspended();
    event Unsuspended();

    /// @notice Address of the Safe.
    function safe() external view returns (address);

    /// @notice Address of the MakinaLite service account.
    function provider() external view returns (address);

    /// @notice Account => Whether the account is an operator.
    function isOperator(address account) external view returns (bool);

    /// @notice Account => Whether the account is a guardian.
    function isGuardian(address account) external view returns (bool);

    /// @notice True if the contract is in lockdown mode, false otherwise.
    function lockdownMode() external view returns (bool);

    /// @notice True if the contract is suspended by the provider, false otherwise.
    function suspendedByProvider() external view returns (bool);

    /// @notice True if the contract is paused by a guardian, false otherwise.
    function paused() external view returns (bool);

    /// @notice Sets the provider address.
    /// @param newProvider The address of the new provider.
    function setProvider(address newProvider) external;

    /// @notice Adds a new operator.
    /// @param newOperator The address of the new operator.
    function addOperator(address newOperator) external;

    /// @notice Removes an operator.
    /// @param operator The address of the operator to remove.
    function removeOperator(address operator) external;

    /// @notice Adds a new guardian.
    /// @param newGuardian The address of the new guardian.
    function addGuardian(address newGuardian) external;

    /// @notice Removes a guardian.
    /// @param guardian The address of the guardian to remove.
    function removeGuardian(address guardian) external;

    /// @notice Sets the lockdown mode.
    /// @param enabled True to enable lockdown mode, false to disable it.
    function setLockdownMode(bool enabled) external;

    /// @notice Suspends operations. Used by the provider to enforce service restrictions.
    function suspend() external;

    /// @notice Restores operations after a provider suspension.
    function unsuspend() external;

    /// @notice Pauses operations. Used by a guardian in case of emergency.
    function pause() external;

    /// @notice Unpauses operations after an emergency pause.
    function unpause() external;
}

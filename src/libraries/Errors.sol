// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

library Errors {
    error AlreadyGuardian();
    error AlreadyOperator();
    error NotGuardian();
    error NotOperator();
    error Paused();
    error ProtectedGuardian();
    error Suspended();
    error UnauthorizedCaller();
}

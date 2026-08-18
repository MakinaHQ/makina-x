// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @dev MockERC6909 contract for testing use only with support for:
///       - direct minting and burning of tokens
///       - reentrancy scheduling
contract MockERC6909 is ERC6909 {
    enum Type {
        No,
        Before,
        After
    }

    Type private _reenterType;
    address private _reenterTarget;
    bytes private _reenterData;

    /// @notice Function to directly call _mint of ERC6909 for minting "amount" number of tokens of given id.
    /// See {ERC6909-_mint}.
    function mint(address receiver, uint256 id, uint256 amount) public {
        _mint(receiver, id, amount);
    }

    /// @notice Function to directly call _burn of ERC6909 for burning "amount" number of tokens of given id.
    /// See {ERC6909-_burn}.
    function burn(address account, uint256 id, uint256 amount) public {
        _burn(account, id, amount);
    }

    /// @notice Function to schedule a reentrancy call to the target contract.
    function scheduleReenter(Type when, address target, bytes calldata data) external {
        _reenterType = when;
        _reenterTarget = target;
        _reenterData = data;
    }

    function _update(address from, address to, uint256 id, uint256 amount) internal override {
        if (_reenterType == Type.Before) {
            _reenterType = Type.No;
            Address.functionCall(_reenterTarget, _reenterData);
        }
        super._update(from, to, id, amount);
        if (_reenterType == Type.After) {
            _reenterType = Type.No;
            Address.functionCall(_reenterTarget, _reenterData);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @dev MockERC721 contract for testing use only with support for:
///       - direct minting and burning of tokens
///       - reentrancy scheduling
contract MockERC721 is ERC721 {
    enum Type {
        No,
        Before,
        After
    }

    Type private _reenterType;
    address private _reenterTarget;
    bytes private _reenterData;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /// @notice Function to directly call _mint of ERC721 for minting the token of given id.
    /// See {ERC721-_mint}.
    function mint(address receiver, uint256 tokenId) public {
        _mint(receiver, tokenId);
    }

    /// @notice Function to directly call _burn of ERC721 for burning the token of given id.
    /// See {ERC721-_burn}.
    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    /// @notice Function to schedule a reentrancy call to the target contract.
    function scheduleReenter(Type when, address target, bytes calldata data) external {
        _reenterType = when;
        _reenterTarget = target;
        _reenterData = data;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (_reenterType == Type.Before) {
            _reenterType = Type.No;
            Address.functionCall(_reenterTarget, _reenterData);
        }
        address from = super._update(to, tokenId, auth);
        if (_reenterType == Type.After) {
            _reenterType = Type.No;
            Address.functionCall(_reenterTarget, _reenterData);
        }
        return from;
    }
}

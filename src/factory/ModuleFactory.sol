// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {Errors} from "../libraries/Errors.sol";
import {IMakinaLiteModule} from "../interfaces/IMakinaLiteModule.sol";
import {IMakinaLiteRegistry} from "../interfaces/IMakinaLiteRegistry.sol";
import {MakinaLiteContext} from "../utils/MakinaLiteContext.sol";
import {IModuleFactory} from "../interfaces/IModuleFactory.sol";

contract ModuleFactory is MakinaLiteContext, AccessManagedUpgradeable, IModuleFactory {
    /// @custom:storage-location erc7201:makina.storage.ModuleFactory
    struct ModuleFactoryStorage {
        mapping(address module => bool isModule) _isMakinaLiteModule;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.ModuleFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ModuleFactoryStorageLocation =
        0x13c0aa9cf01ea4a55fe2c5301d9fa8e9cd0e82c169c42cf1800b1faae24f0800;

    function _getModuleFactoryStorage() private pure returns (ModuleFactoryStorage storage $) {
        assembly {
            $.slot := ModuleFactoryStorageLocation
        }
    }

    constructor(address _registry) MakinaLiteContext(_registry) {}

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc IModuleFactory
    function isMakinaLiteModule(address module) external view returns (bool) {
        return _getModuleFactoryStorage()._isMakinaLiteModule[module];
    }

    /// @inheritdoc IModuleFactory
    function createModule(IMakinaLiteModule.MakinaLiteModuleInitParams calldata params, bytes32 salt)
        external
        restricted
        returns (address)
    {
        ModuleFactoryStorage storage $ = _getModuleFactoryStorage();

        if (salt == bytes32(0)) {
            revert Errors.ZeroSalt();
        }

        address implementation = IMakinaLiteRegistry(registry).moduleImplementation();

        address module = Clones.cloneDeterministic(implementation, salt);
        IMakinaLiteModule(module).initialize(params);

        emit MakinaLiteModuleCreated(module, implementation);

        $._isMakinaLiteModule[module] = true;

        return module;
    }
}

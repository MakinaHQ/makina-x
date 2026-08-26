// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

abstract contract SaltDomains {
    /// @dev MakinaXModule clones are non-upgradeable, so the implementation salt domain is versioned.
    bytes32 internal constant MAKINA_X_MODULE_IMPLEM_SALT_DOMAIN = keccak256("makinax.salt.MakinaXModule.v1.1.0");

    /// @dev FlashLoanModule is non-upgradeable, so its salt domain is versioned.
    bytes32 internal constant FLASHLOAN_MODULE_SALT_DOMAIN = keccak256("makinax.salt.FlashLoanModule.v1.1.0");

    bytes32 internal constant MAKINA_X_REGISTRY_SALT_DOMAIN = keccak256("makinax.salt.MakinaXRegistry");

    bytes32 internal constant MODULE_FACTORY_SALT_DOMAIN = keccak256("makinax.salt.ModuleFactory");

    bytes32 internal constant ACROSS_V4_BRIDGE_ENCODER_SALT_DOMAIN = keccak256("makinax.salt.AcrossV4BridgeEncoder");

    bytes32 internal constant LAYER_ZERO_V2_BRIDGE_ENCODER_SALT_DOMAIN =
        keccak256("makinax.salt.LayerZeroV2BridgeEncoder");

    bytes32 internal constant CCTP_V2_BRIDGE_ENCODER_SALT_DOMAIN = keccak256("makinax.salt.CctpV2BridgeEncoder");
}

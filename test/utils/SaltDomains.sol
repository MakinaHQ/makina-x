// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

abstract contract SaltDomains {
    bytes32 internal constant MAKINA_LITE_REGISTRY_SALT_DOMAIN = keccak256("makina.salt.MakinaLiteRegistry");

    bytes32 internal constant MODULE_FACTORY_SALT_DOMAIN = keccak256("makina.salt.ModuleFactory");

    bytes32 internal constant ACROSS_V4_BRIDGE_ENCODER_SALT_DOMAIN = keccak256("makina.salt.AcrossV4BridgeEncoder");

    bytes32 internal constant LAYER_ZERO_V2_BRIDGE_ENCODER_SALT_DOMAIN =
        keccak256("makina.salt.LayerZeroV2BridgeEncoder");

    bytes32 internal constant CCTP_V2_BRIDGE_ENCODER_SALT_DOMAIN = keccak256("makina.salt.CctpV2BridgeEncoder");
}

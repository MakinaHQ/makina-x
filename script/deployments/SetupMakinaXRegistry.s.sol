// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";

import {SetupMakinaX} from "./SetupMakinaX.s.sol";

/// @notice Configures the MakinaXRegistry component addresses.
/// @dev See `SetupMakinaX` for the env vars.
contract SetupMakinaXRegistry is SetupMakinaX {
    function _calls() internal view override returns (Call[] memory) {
        address feeCollector = vm.parseJsonAddress(deploymentInputJson, ".feeCollector");

        MakinaXInfra memory infra = _readInfra();

        return _concatCalls(_registrySetupCalls(infra, feeCollector), _bridgeEncoderRegistrationCalls(infra.registry));
    }

    function _bridgeEncoderRegistrationCalls(MakinaXRegistry registry) internal view returns (Call[] memory calls) {
        (uint16[] memory bridgeIds, address[] memory encoders) = _readBridgeEncoders();

        calls = new Call[](bridgeIds.length);
        for (uint256 i; i < bridgeIds.length; ++i) {
            calls[i] =
                Call(address(registry), abi.encodeCall(MakinaXRegistry.setBridgeEncoder, (bridgeIds[i], encoders[i])));
        }
    }

    function _targetLabel() internal pure override returns (string memory) {
        return "Target (MakinaXRegistry):";
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FlashLoanModule} from "../../src/flash-loans/FlashLoanModule.sol";
import {MakinaXRegistry} from "../../src/registry/MakinaXRegistry.sol";
import {ModuleFactory} from "../../src/factory/ModuleFactory.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Configures the MakinaXRegistry component addresses and registers the deployed bridge encoders.
/// @dev The broadcasting account must have the `INFRA_CONFIG_ROLE` in the AccessManager provided in the infra
///      input file.
///
/// Env vars:
///   INFRA_INPUT_FILENAME   - infra input file holding the fee collector and bridge targets
///                            (under script/deployments/inputs/makina-x-infra/)
///   INFRA_OUTPUT_FILENAME  - infra output file holding the deployed contract addresses
///                            (under script/deployments/outputs/makina-x-infra/)
///   VIEW_MODE (optional)   - if true, logs the MakinaXRegistry calls calldata instead of broadcasting
///   TEST_SENDER (optional) - account to broadcast from
contract SetupMakinaXRegistry is Base, Script {
    using stdJson for string;

    string public deploymentInputJson;
    string public deploymentOutputJson;

    bool public viewMode;

    constructor() {
        viewMode = vm.envOr("VIEW_MODE", false);

        string memory deploymentInputFilename = vm.envString("INFRA_INPUT_FILENAME");
        string memory deploymentOutputFilename = vm.envString("INFRA_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load deployment input params
        string memory deploymentInputPath = string.concat(basePath, "inputs/makina-x-infra/");
        deploymentInputPath = string.concat(deploymentInputPath, deploymentInputFilename);
        deploymentInputJson = vm.readFile(deploymentInputPath);

        // load deployment output params
        string memory deploymentOutputPath = string.concat(basePath, "outputs/makina-x-infra/");
        deploymentOutputPath = string.concat(deploymentOutputPath, deploymentOutputFilename);
        deploymentOutputJson = vm.readFile(deploymentOutputPath);
    }

    function run() public {
        address feeCollector = vm.parseJsonAddress(deploymentInputJson, ".feeCollector");

        MakinaXInfra memory infra = _readInfra();

        Call[] memory calls = _registrySetupAndEncoderCalls(infra, feeCollector);

        if (viewMode) {
            _logCalls(calls);
            return;
        }

        address sender = vm.envOr("TEST_SENDER", address(0));
        if (sender != address(0)) {
            vm.startBroadcast(sender);
        } else {
            vm.startBroadcast();
        }

        _executeCalls(calls);

        vm.stopBroadcast();
    }

    function _readInfra() internal view returns (MakinaXInfra memory) {
        return MakinaXInfra({
            registry: MakinaXRegistry(vm.parseJsonAddress(deploymentOutputJson, ".MakinaXRegistry")),
            moduleFactory: ModuleFactory(vm.parseJsonAddress(deploymentOutputJson, ".ModuleFactory")),
            makinaXModuleImplem: vm.parseJsonAddress(deploymentOutputJson, ".MakinaXModuleImplem"),
            flashLoanModule: FlashLoanModule(vm.parseJsonAddress(deploymentOutputJson, ".FlashLoanModule"))
        });
    }

    /// @dev Combines the registry component setters with the bridge encoder registrations, in that order.
    function _registrySetupAndEncoderCalls(MakinaXInfra memory infra, address feeCollector)
        internal
        view
        returns (Call[] memory calls)
    {
        Call[] memory setupCalls = _registrySetupCalls(infra, feeCollector);
        Call[] memory encoderCalls = _bridgeEncoderCalls(infra.registry);

        calls = new Call[](setupCalls.length + encoderCalls.length);
        for (uint256 i; i < setupCalls.length; ++i) {
            calls[i] = setupCalls[i];
        }
        for (uint256 i; i < encoderCalls.length; ++i) {
            calls[setupCalls.length + i] = encoderCalls[i];
        }
    }

    function _bridgeEncoderCalls(MakinaXRegistry registry) internal view returns (Call[] memory calls) {
        uint256 len = _bridgesTargetsLength();
        calls = new Call[](len);
        for (uint256 i; i < len; ++i) {
            uint16 bridgeId = uint16(
                vm.parseJsonUint(deploymentInputJson, string.concat(".bridgesTargets[", vm.toString(i), "].bridgeId"))
            );
            address encoder = vm.parseJsonAddress(
                deploymentOutputJson, string.concat(".BridgeEncoders.", vm.toString(uint256(bridgeId)))
            );
            calls[i] = Call(address(registry), abi.encodeCall(MakinaXRegistry.setBridgeEncoder, (bridgeId, encoder)));
        }
    }

    function _bridgesTargetsLength() internal view returns (uint256 len) {
        while (vm.keyExistsJson(deploymentInputJson, string.concat(".bridgesTargets[", vm.toString(len), "]"))) {
            ++len;
        }
    }

    function _logCalls(Call[] memory calls) internal pure {
        for (uint256 i; i < calls.length; ++i) {
            console2.log("Target (MakinaXRegistry):", calls[i].target);
            console2.log("Calldata:");
            console2.logBytes(calls[i].data);
        }
    }
}

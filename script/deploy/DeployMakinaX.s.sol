// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Deploys the MakinaX infra and runs its registry and AccessManager setup in a single broadcast.
///
/// Env vars:
///   INFRA_INPUT_FILENAME     - infra input file holding the deployment parameters
///                              (under script/deploy/inputs/infra/)
///   INFRA_OUTPUT_FILENAME    - infra output file to write the deployed contract addresses to
///                              (under script/deploy/outputs/infra/)
///   SKIP_AM_SETUP (optional) - if true, skips the AccessManager function roles and role grants setup,
///                              leaving the deployer as sole admin (for staging infra deployments)
contract DeployMakinaX is Base, Script, CreateXUtils {
    MakinaXInfra private _infra;
    uint16[] private _bridgeIds;
    address[] private _bridgeEncoders;

    string public inputJson;
    string public outputPath;

    address public deployer;

    bool public skipAMSetup;

    bool public writeOutput = true;

    constructor() {
        skipAMSetup = vm.envOr("SKIP_AM_SETUP", false);

        string memory inputFilename = vm.envString("INFRA_INPUT_FILENAME");
        string memory outputFilename = vm.envString("INFRA_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/infra/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/infra/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (MakinaXInfra memory, uint16[] memory, address[] memory) {
        return (_infra, _bridgeIds, _bridgeEncoders);
    }

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    /// @dev Test hook: leaves the deployer as sole admin (restricted functions default to ADMIN_ROLE)
    ///      and skips writing the output file.
    function setTestMode() public {
        skipAMSetup = true;
        writeOutput = false;
    }

    function _deploySetupBefore() internal {
        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _coreSetup() internal {
        address feeCollector = vm.parseJsonAddress(inputJson, ".feeCollector");
        FlashLoanProviders memory flProviders =
            FlashLoanProviders({morpho: vm.parseJsonAddress(inputJson, ".flashLoanProviders.morpho")});
        address defaultProvider = vm.parseJsonAddress(inputJson, ".defaultProvider");
        uint256 defaultSwapFeeRate = vm.parseJsonUint(inputJson, ".defaultSwapFeeRate");
        bool freeDeployment = vm.parseJsonBool(inputJson, ".freeDeployment");

        // Deploy the AccessManager with the deployer as temporary admin, then the infrastructure wired to it.
        _infra = deployMakinaXInfra(deployer, flProviders, defaultProvider, defaultSwapFeeRate, freeDeployment);
        _deployBridgeEncoders(address(_infra.accessManager));

        // Until function roles are assigned below, restricted functions default to the deployer's ADMIN_ROLE,
        // allowing the whole setup to run in this single broadcast.
        setupMakinaXRegistry(_infra, feeCollector, _bridgeIds, _bridgeEncoders);

        if (!skipAMSetup) {
            // Setup AccessManager function roles.
            setupAMFunctionRoles(_infra, _bridgeIds, _bridgeEncoders);

            // Grant the configured roles, revoke the deployer.
            setupAccessManagerRoles(
                _infra.accessManager, _parseSuperAdminRoleGrant(), _parseOtherRoleGrants(), deployer
            );
        }

        // Transfer the ownership of the AccessManager's proxy admin to the AccessManager itself.
        transferAccessManagerOwnership(_infra.accessManager);
    }

    function _deploySetupAfter() internal {
        // finish broadcasting transactions
        vm.stopBroadcast();

        if (!writeOutput) {
            return;
        }

        string memory key = "key-deploy-infra-output-file";

        // write to file
        vm.serializeAddress(key, "AccessManager", address(_infra.accessManager));
        vm.serializeAddress(key, "MakinaXRegistry", address(_infra.registry));
        vm.serializeAddress(key, "ModuleFactory", address(_infra.moduleFactory));
        vm.serializeAddress(key, "MakinaXModuleImplem", _infra.makinaXModuleImplem);
        vm.serializeAddress(key, "FlashLoanModule", address(_infra.flashLoanModule));

        string memory bridgeEncoderList;
        string memory beKey = "key-bridge-encoder-list";
        for (uint256 i; i < _bridgeIds.length; ++i) {
            bridgeEncoderList = vm.serializeAddress(beKey, vm.toString(_bridgeIds[i]), _bridgeEncoders[i]);
        }
        vm.writeJson(vm.serializeString(key, "BridgeEncoders", bridgeEncoderList), outputPath);
    }

    function _deployBridgeEncoders(address accessManager) internal {
        uint256 len = _bridgesTargetsLength();
        for (uint256 i; i < len; ++i) {
            string memory base = string.concat(".bridgesTargets[", vm.toString(i), "]");
            uint16 bridgeId = uint16(vm.parseJsonUint(inputJson, string.concat(base, ".bridgeId")));

            address encoder;
            if (bridgeId == ACROSS_V4_BRIDGE_ID) {
                address acrossV4SpokePool = vm.parseJsonAddress(inputJson, string.concat(base, ".acrossV4SpokePool"));
                encoder = address(_deployAcrossV4BridgeEncoder(accessManager, accessManager, acrossV4SpokePool));
            } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
                encoder = address(_deployLayerZeroV2BridgeEncoder(accessManager, accessManager));
            } else if (bridgeId == CCTP_V2_BRIDGE_ID) {
                address cctpV2TokenMessenger =
                    vm.parseJsonAddress(inputJson, string.concat(base, ".cctpV2TokenMessenger"));
                encoder = address(_deployCctpV2BridgeEncoder(accessManager, accessManager, cctpV2TokenMessenger));
            } else {
                revert("DeployMakinaX: unsupported bridgeId");
            }

            _bridgeIds.push(bridgeId);
            _bridgeEncoders.push(encoder);
        }
    }

    function _parseSuperAdminRoleGrant() internal view returns (AMRoleGrant memory) {
        return AMRoleGrant({
            roleId: 0,
            account: vm.parseJsonAddress(inputJson, ".superAdminRoleGrant.account"),
            executionDelay: uint32(vm.parseJsonUint(inputJson, ".superAdminRoleGrant.executionDelay"))
        });
    }

    function _parseOtherRoleGrants() internal view returns (AMRoleGrant[] memory roleGrants) {
        uint256 len;
        while (vm.keyExistsJson(inputJson, string.concat(".otherRoleGrants[", vm.toString(len), "]"))) {
            ++len;
        }

        roleGrants = new AMRoleGrant[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = string.concat(".otherRoleGrants[", vm.toString(i), "]");
            roleGrants[i] = AMRoleGrant({
                roleId: uint64(vm.parseJsonUint(inputJson, string.concat(base, ".roleId"))),
                account: vm.parseJsonAddress(inputJson, string.concat(base, ".account")),
                executionDelay: uint32(vm.parseJsonUint(inputJson, string.concat(base, ".executionDelay")))
            });
        }
    }

    function _bridgesTargetsLength() internal view returns (uint256 len) {
        while (vm.keyExistsJson(inputJson, string.concat(".bridgesTargets[", vm.toString(len), "]"))) {
            ++len;
        }
    }

    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address) {
        return _deployCodeCreateX(bytecode, salt, deployer);
    }
}

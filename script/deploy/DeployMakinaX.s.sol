// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Deploys the MakinaX infra and runs its registry and AccessManager setup in a single broadcast.
///
/// Env vars (unless `setFilenames` was called):
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

    /// @dev Test hook to set the input and output filenames explicitly, instead of having `run` resolve them from
    ///      the env vars. An empty output filename skips writing the output file.
    function setFilenames(string memory inputFilename, string memory outputFilename) public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/infra/", inputFilename));

        outputPath = bytes(outputFilename).length == 0 ? "" : string.concat(basePath, "outputs/infra/", outputFilename);
    }

    /// @dev Test hook: leaves the deployer as sole admin (restricted functions default to ADMIN_ROLE).
    function setSkipAMSetup(bool _skip) public {
        skipAMSetup = _skip;
    }

    /// @dev Reads `SKIP_AM_SETUP` and calls `setFilenames` with this script's env vars.
    function loadParamsFromEnv() public {
        skipAMSetup = vm.envOr("SKIP_AM_SETUP", false);
        setFilenames(vm.envString("INFRA_INPUT_FILENAME"), vm.envString("INFRA_OUTPUT_FILENAME"));
    }

    function deployment() public view returns (MakinaXInfra memory, uint16[] memory, address[] memory) {
        return (_infra, _bridgeIds, _bridgeEncoders);
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            loadParamsFromEnv();
        }

        vm.startBroadcast();

        (, deployer,) = vm.readCallers();

        _coreSetup();

        vm.stopBroadcast();

        if (bytes(outputPath).length != 0) {
            _writeOutput();
        }
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

    function _writeOutput() internal {
        string memory key = "key-deploy-infra-output-file";

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

    /// @dev Deploys through CreateX at the deployer-bound address and asserts it. An occupied CREATE2 slot (zero salt
    ///      domain, used for implementations) is reused: that address is bound to the init code hash, so the code
    ///      there is this exact bytecode. An occupied CREATE3 slot reverts before broadcasting.
    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address deployed) {
        deployed = _computeCreateXAddress(bytecode, salt, deployer);

        if (deployed.code.length != 0) {
            if (salt == 0) {
                return deployed;
            }
            revert(string.concat("DeployMakinaX: CREATE3 target already has code: ", vm.toString(deployed)));
        }

        require(_deployCodeCreateX(bytecode, salt, deployer) == deployed, "DeployMakinaX: CreateX address mismatch");
    }
}

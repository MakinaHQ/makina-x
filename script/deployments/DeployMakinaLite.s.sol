// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployMakinaLite is Base, Script, CreateXUtils {
    using stdJson for string;

    MakinaLiteInfra private _infra;
    uint16[] private _bridgeIds;
    address[] private _bridgeEncoders;

    string public inputJson;
    string public outputPath;

    address public deployer;

    constructor() {
        string memory inputFilename = vm.envString("INFRA_INPUT_FILENAME");
        string memory outputFilename = vm.envString("INFRA_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/makina-lite-infra/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/makina-lite-infra/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (MakinaLiteInfra memory, uint16[] memory, address[] memory) {
        return (_infra, _bridgeIds, _bridgeEncoders);
    }

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _deploySetupBefore() internal {
        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _coreSetup() internal {
        address accessManager = vm.parseJsonAddress(inputJson, ".accessManager");
        address weirollVM = vm.parseJsonAddress(inputJson, ".weirollVM");
        FlashLoanProviders memory flProviders =
            FlashLoanProviders({morpho: vm.parseJsonAddress(inputJson, ".flashLoanProviders.morpho")});

        _infra = deployMakinaLiteInfra(accessManager, weirollVM, flProviders);

        _deployBridgeEncoders(accessManager);
    }

    function _deploySetupAfter() internal {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-lite-infra-output-file";

        // write to file
        vm.serializeAddress(key, "MakinaLiteRegistry", address(_infra.registry));
        vm.serializeAddress(key, "ModuleFactory", address(_infra.moduleFactory));
        vm.serializeAddress(key, "MakinaLiteModuleImplem", _infra.makinaLiteModuleImplem);
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
                encoder = address(_deployAcrossV4BridgeEncoder(deployer, accessManager, acrossV4SpokePool));
            } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
                encoder = address(_deployLayerZeroV2BridgeEncoder(deployer, accessManager));
            } else if (bridgeId == CCTP_V2_BRIDGE_ID) {
                address cctpV2TokenMessenger =
                    vm.parseJsonAddress(inputJson, string.concat(base, ".cctpV2TokenMessenger"));
                encoder = address(_deployCctpV2BridgeEncoder(deployer, accessManager, cctpV2TokenMessenger));
            } else {
                revert("DeployMakinaLite: unsupported bridgeId");
            }

            _bridgeIds.push(bridgeId);
            _bridgeEncoders.push(encoder);
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

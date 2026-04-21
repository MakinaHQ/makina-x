// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract MerkleProofHelper {
    using stdJson for string;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal allowedInstrMerkleRoot;

    struct MerkleTreeParams {
        address safe;
        address mockTokenA;
        address mockTokenB;
        address mockVault;
        uint256 mockVaultPosId;
        address mockSupplyModule;
        uint256 mockSupplyModulePosId;
        address mockBorrowModule;
        uint256 mockBorrowModulePosId;
        address flashLoanModule;
        uint256 mockLoopPosId;
    }

    function _generateMerkleData(MerkleTreeParams memory params) internal returns (bytes32) {
        string[] memory command = new string[](17);
        command[0] = "yarn";
        command[1] = "--silent";
        command[2] = "genMerkleDataMock";
        command[3] = vm.toString(params.safe);
        command[4] = vm.toString(params.mockTokenA);
        command[5] = vm.toString(params.mockTokenB);
        command[6] = vm.toString(params.mockVault);
        command[7] = vm.toString(params.mockVaultPosId);
        command[8] = vm.toString(params.mockSupplyModule);
        command[9] = vm.toString(params.mockSupplyModulePosId);
        command[10] = vm.toString(params.mockBorrowModule);
        command[11] = vm.toString(params.mockBorrowModulePosId);
        command[12] = vm.toString(params.flashLoanModule);
        command[13] = vm.toString(params.mockLoopPosId);

        bytes memory out = vm.ffi(command);
        bytes32 root = bytes32(out);

        return root;
    }

    function _getMerkleData() internal view returns (string memory) {
        return
            vm.readFile(
                string.concat(vm.projectRoot(), "/script/merkle/", vm.toString(allowedInstrMerkleRoot), ".json")
            );
    }

    function _getAllowedInstrMerkleRoot() internal view returns (bytes32) {
        return _getMerkleData().readBytes32(".root");
    }

    function _getDeposit4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDepositMock4626");
    }

    function _getRedeem4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRedeemMock4626");
    }

    function _getAccounting4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMock4626");
    }

    function _getSupplyMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofSupplyMockSupplyModule");
    }

    function _getWithdrawMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofWithdrawMockSupplyModule");
    }

    function _getAccountingMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockSupplyModule");
    }

    function _getBorrowMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofBorrowMockBorrowModule");
    }

    function _getRepayMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRepayMockBorrowModule");
    }

    function _getAccountingMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockBorrowModule");
    }

    function _getHarvestMockTokenAInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofHarvestMockTokenA");
    }

    function _getDummyLoopMockFlashLoanModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDummyLoopMockFlashLoanModule");
    }

    function _getAccountingMockFlashLoanModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockFlashLoanModule");
    }

    function _getManageFlashLoanDummyInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDummyManageFlashLoan");
    }
}

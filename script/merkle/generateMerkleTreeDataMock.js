import { ethers } from "ethers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// Arguments to pass :
//  safeAddr
//  mockTokenAAddr
//  mockTokenBAddr
//  mockERC4626Addr
//  mockERC4626PosId
//  mockSupplyModuleAddr
//  mockSupplyModulePosId
//  mockBorrowModuleAddr
//  mockBorrowModulePosId
//  flashLoanModule
//  mockLoopPosId

// Instructions format: [commandsHash, stateHash, stateBitmap, positionId, isDebt, groupId, affectedTokensHash, positionTokensHash, instructionType]

const safeAddr = process.argv[2];
const mockTokenAAddr = process.argv[3];
const mockTokenBAddr = process.argv[4];
const mockERC4626Addr = process.argv[5];
const mockERC4626PosId = process.argv[6];
const mockSupplyModuleAddr = process.argv[7];
const mockSupplyModulePosId = process.argv[8];
const mockBorrowModuleAddr = process.argv[9];
const mockBorrowModulePosId = process.argv[10];
const flashLoanModule = process.argv[11];
const mockLoopPosId = process.argv[12];

const depositMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockTokenBAddr]),
    ethers.concat(["0x6e553f65010102ffffffffff", mockERC4626Addr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockERC4626Addr, 32),
    ethers.zeroPadValue(safeAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockERC4626PosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const redeemMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0xba08765201000102ffffffff", mockERC4626Addr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(safeAddr, 32),
    ethers.zeroPadValue(safeAddr, 32),
  ]),
  "0x60000000000000000000000000000000",
  mockERC4626PosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const accountingMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x38d52e0f02ffffffffffff00", mockERC4626Addr]),
    ethers.concat(["0x70a082310202ffffffffff02", mockERC4626Addr]),
    ethers.concat(["0x4cdad5060202ffffffffff00", mockERC4626Addr]),
  ]),
  getStateHash([ethers.zeroPadValue(safeAddr, 32)]),
  "0x20000000000000000000000000000000",
  mockERC4626PosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([ethers.zeroPadValue(mockERC4626Addr, 32)]),
  "1",
];

const supplyMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockTokenBAddr]),
    ethers.concat(["0x354030230101ffffffffffff", mockSupplyModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockSupplyModuleAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const withdrawMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x2e1a7d4d0100ffffffffffff", mockSupplyModuleAddr]),
  ]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const accountingMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x1aefb1070200ffffffffff00", mockSupplyModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(safeAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([ethers.zeroPadValue(mockSupplyModuleAddr, 32)]),
  "1",
];

const borrowMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xc5ebeaec0100ffffffffffff", mockBorrowModuleAddr]),
  ]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const repayMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockTokenBAddr]),
    ethers.concat(["0x371fd8e60101ffffffffffff", mockBorrowModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockBorrowModuleAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([]),
  "0",
];

const accountingMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xd283e75f0200ffffffffff00", mockBorrowModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(safeAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  "0",
  keccak256EncodePacked([ethers.zeroPadValue(mockTokenBAddr, 32)]),
  keccak256EncodePacked([ethers.zeroPadValue(mockBorrowModuleAddr, 32)]),
  "1",
];

const harvestMockTokenAInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x40c10f19010001ffffffffff", mockTokenAAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(safeAddr, 32)]),
  "0x80000000000000000000000000000000",
  0,
  false,
  "0",
  keccak256EncodePacked([]),
  keccak256EncodePacked([]),
  "2",
];

const dummyLoopMockFlashLoanModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xb1485fa00180ffffffffffff", flashLoanModule]),
  ]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockLoopPosId,
  false,
  "0",
  keccak256EncodePacked([]),
  keccak256EncodePacked([]),
  "0",
];

const accountingMockFlashLoanModuleInstruction = [
  keccak256EncodePacked([]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockLoopPosId,
  false,
  "0",
  keccak256EncodePacked([]),
  keccak256EncodePacked([]),
  "1",
];

const dummyManageFlashLoanInstruction = [
  keccak256EncodePacked([]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockLoopPosId,
  false,
  "0",
  keccak256EncodePacked([]),
  keccak256EncodePacked([]),
  "3",
];

const values = [
  depositMock4626Instruction,
  redeemMock4626Instruction,
  accountingMock4626Instruction,
  supplyMockSupplyModuleInstruction,
  withdrawMockSupplyModuleInstruction,
  accountingMockSupplyModuleInstruction,
  borrowMockBorrowModuleInstruction,
  repayMockBorrowModuleInstruction,
  accountingMockBorrowModuleInstruction,
  harvestMockTokenAInstruction,
  dummyLoopMockFlashLoanModuleInstruction,
  accountingMockFlashLoanModuleInstruction,
  dummyManageFlashLoanInstruction,
];

const tree = StandardMerkleTree.of(values, [
  "bytes32",
  "bytes32",
  "uint128",
  "uint256",
  "bool",
  "uint256",
  "bytes32",
  "bytes32",
  "uint256",
]);

const treeData = {
  root: tree.root,
  proofDepositMock4626: tree.getProof(0),
  proofRedeemMock4626: tree.getProof(1),
  proofAccountingMock4626: tree.getProof(2),
  proofSupplyMockSupplyModule: tree.getProof(3),
  proofWithdrawMockSupplyModule: tree.getProof(4),
  proofAccountingMockSupplyModule: tree.getProof(5),
  proofBorrowMockBorrowModule: tree.getProof(6),
  proofRepayMockBorrowModule: tree.getProof(7),
  proofAccountingMockBorrowModule: tree.getProof(8),
  proofHarvestMockTokenA: tree.getProof(9),
  proofDummyLoopMockFlashLoanModule: tree.getProof(10),
  proofAccountingMockFlashLoanModule: tree.getProof(11),
  proofDummyManageFlashLoan: tree.getProof(12),
};

fs.writeFileSync(
  "script/merkle/" + tree.root + ".json",
  JSON.stringify(treeData, null, 2) + "\n",
);

process.stdout.write(tree.root);

function keccak256EncodePacked(list) {
  return ethers.keccak256(ethers.concat(list));
}

function getStateHash(state) {
  return state.length > 0
    ? keccak256EncodePacked(state.map((value) => ethers.keccak256(value)))
    : ethers.ZeroHash;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract WeirollComponent_Integration_Concrete_Test is Integration_Concrete_Test {
    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        MerkleTreeParams memory params = MerkleTreeParams({
            safe: address(safe),
            mockTokenA: address(tokenA),
            mockTokenB: address(tokenB),
            mockVault: address(vault),
            mockVaultPosId: VAULT_POS_ID,
            mockSupplyModule: address(supplyModule),
            mockSupplyModulePosId: SUPPLY_POS_ID,
            mockBorrowModule: address(borrowModule),
            mockBorrowModulePosId: BORROW_POS_ID,
            flashLoanModule: address(flashLoanModule),
            mockLoopPosId: LOOP_POS_ID
        });

        // generate merkle tree for instructions involving mock contracts
        allowedInstrMerkleRoot = _generateMerkleData(params);

        vm.prank(address(safe));
        makinaXModule.setAllowedInstrRoot(allowedInstrMerkleRoot);
    }
}

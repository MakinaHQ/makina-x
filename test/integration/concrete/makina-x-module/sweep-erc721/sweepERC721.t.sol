// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.35;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaXModule} from "src/interfaces/IMakinaXModule.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract SweepERC721_Integration_Concrete_Test is Integration_Concrete_Test {
    uint256 internal constant TEST_TOKEN_ID = 42;

    MockERC721 internal nftA;

    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        nftA = new MockERC721("nftA", "NA");
    }

    function test_RevertWhen_ReentrantCall() public {
        nftA.mint(address(makinaXModule), TEST_TOKEN_ID);

        nftA.scheduleReenter(
            MockERC721.Type.Before,
            address(makinaXModule),
            abi.encodeCall(IMakinaXModule.sweepERC721, (address(nftA), TEST_TOKEN_ID))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(safe));
        makinaXModule.sweepERC721(address(nftA), TEST_TOKEN_ID);
    }

    function test_RevertGiven_CallerNotSafe() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        makinaXModule.sweepERC721(address(0), 0);
    }

    function test_SweepERC721() public {
        nftA.mint(address(makinaXModule), TEST_TOKEN_ID);

        vm.prank(address(safe));
        makinaXModule.sweepERC721(address(nftA), TEST_TOKEN_ID);

        assertEq(nftA.balanceOf(address(makinaXModule)), 0);
        assertEq(nftA.balanceOf(address(safe)), 1);
        assertEq(nftA.ownerOf(TEST_TOKEN_ID), address(safe));
    }
}

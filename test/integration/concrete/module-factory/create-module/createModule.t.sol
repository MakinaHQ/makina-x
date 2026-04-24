// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Errors as OZErrors} from "@openzeppelin/contracts/utils/Errors.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IMakinaLiteModule} from "src/interfaces/IMakinaLiteModule.sol";
import {IModuleFactory} from "src/interfaces/IModuleFactory.sol";
import {MakinaLiteModule} from "src/MakinaLiteModule.sol";

import {Integration_Concrete_Test} from "../../IntegrationConcrete.t.sol";

contract CreateModule_Integration_Concrete_Test is Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IMakinaLiteModule.MakinaLiteModuleInitParams memory params;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        moduleFactory.createModule(params, bytes32(0));
    }

    function test_RevertWhen_ZeroSalt() public {
        IMakinaLiteModule.MakinaLiteModuleInitParams memory params;

        vm.prank(dao);
        vm.expectRevert(Errors.ZeroSalt.selector);
        moduleFactory.createModule(params, bytes32(0));
    }

    function test_RevertWhen_SaltAlreadyUsed() public {
        IMakinaLiteModule.MakinaLiteModuleInitParams memory params;

        vm.prank(dao);
        vm.expectRevert(OZErrors.FailedDeployment.selector);
        moduleFactory.createModule(params, TEST_DEPLOYMENT_SALT);
    }

    function test_RevertWhen_ZeroSafe() public {
        IMakinaLiteModule.MakinaLiteModuleInitParams memory params;
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.prank(dao);
        vm.expectRevert(Errors.ZeroAddress.selector);
        moduleFactory.createModule(params, salt);
    }

    function test_CreateModule() public {
        bytes32 initialAllowedInstrRoot = bytes32("0x12345");
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        address expectedModuleAddr =
            Clones.predictDeterministicAddress(makinaLiteModuleImplem, salt, address(moduleFactory));

        vm.expectEmit(true, true, false, false, address(moduleFactory));
        emit IModuleFactory.MakinaLiteModuleCreated(expectedModuleAddr, makinaLiteModuleImplem);

        vm.prank(dao);
        makinaLiteModule = MakinaLiteModule(
            payable(moduleFactory.createModule(
                    IMakinaLiteModule.MakinaLiteModuleInitParams({
                        safe: address(safe),
                        initialProvider: dao,
                        initialAllowedInstrRoot: initialAllowedInstrRoot,
                        initialMaxPositionIncreaseLossBps: DEFAULT_MAX_POS_INCREASE_LOSS_BPS,
                        initialMaxPositionDecreaseLossBps: DEFAULT_MAX_POS_DECREASE_LOSS_BPS,
                        initialMaxSwapLossBps: DEFAULT_MAX_SWAP_LOSS_BPS,
                        initialSwapFeeRate: DEFAULT_SWAP_FEE_RATE
                    }),
                    salt
                ))
        );

        assertTrue(moduleFactory.isMakinaLiteModule(address(makinaLiteModule)));

        assertEq(makinaLiteModule.registry(), address(registry));
        assertEq(makinaLiteModule.safe(), address(safe));
        assertEq(makinaLiteModule.provider(), dao);
        assertFalse(makinaLiteModule.paused());
        assertFalse(makinaLiteModule.suspendedByProvider());
        assertEq(makinaLiteModule.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(makinaLiteModule.maxPositionIncreaseLossBps(), DEFAULT_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(makinaLiteModule.maxPositionDecreaseLossBps(), DEFAULT_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(makinaLiteModule.maxSwapLossBps(), DEFAULT_MAX_SWAP_LOSS_BPS);
        assertEq(makinaLiteModule.swapFeeRate(), DEFAULT_SWAP_FEE_RATE);
    }
}

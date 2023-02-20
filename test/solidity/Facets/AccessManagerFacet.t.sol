// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { DSTest } from "ds-test/test.sol";
import { console } from "../utils/Console.sol";
import { DiamondTest, RubicMultiProxy } from "../utils/DiamondTest.sol";
import { Vm } from "forge-std/Vm.sol";
import { AccessManagerFacet } from "rubic/Facets/AccessManagerFacet.sol";
import { LibAccess } from "rubic/Libraries/LibAccess.sol";
import { UnAuthorized } from "rubic/Errors/GenericErrors.sol";

contract RestrictedContract {
    function restrictedMethod() external view returns (bool) {
        LibAccess.enforceAccessControl();
        return true;
    }
}

contract AccessManagerFacetTest is DSTest, DiamondTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    RubicMultiProxy internal diamond;
    AccessManagerFacet internal accessMgr;
    RestrictedContract internal restricted;

    function setUp() public {
        (diamond, ) = createDiamond(address(this), 1);
        accessMgr = new AccessManagerFacet();
        restricted = new RestrictedContract();

        // Already added in DiamondTest.sol
        //        bytes4[] memory functionSelectors = new bytes4[](1);
        //        functionSelectors[0] = accessMgr.setCanExecute.selector;
        //        addFacet(diamond, address(accessMgr), functionSelectors);

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = restricted.restrictedMethod.selector;
        addFacet(diamond, address(restricted), functionSelectors);

        accessMgr = AccessManagerFacet(address(diamond));
        restricted = RestrictedContract(address(diamond));
    }

    function testAccessIsRestricted() public {
        vm.expectRevert(UnAuthorized.selector);
        vm.prank(address(0xb33f));
        restricted.restrictedMethod();
    }

    function testCanGrantAccess() public {
        accessMgr.setCanExecute(
            RestrictedContract.restrictedMethod.selector,
            address(0xb33f),
            true
        );
        vm.prank(address(0xb33f));
        restricted.restrictedMethod();
    }

    function testCanRemoveAccess() public {
        accessMgr.setCanExecute(
            RestrictedContract.restrictedMethod.selector,
            address(0xb33f),
            true
        );
        accessMgr.setCanExecute(
            RestrictedContract.restrictedMethod.selector,
            address(0xb33f),
            false
        );
        vm.expectRevert(UnAuthorized.selector);
        vm.prank(address(0xb33f));
        restricted.restrictedMethod();
    }
}

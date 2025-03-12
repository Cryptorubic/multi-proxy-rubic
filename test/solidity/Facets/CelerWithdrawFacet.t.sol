// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.17;

import { TestBase, RubicMultiProxy } from "../utils/TestBaseFacet.sol";
import { CelerWithdrawFacet, ICelerWithdraw } from "rubic/Facets/CelerWithdrawFacet.sol";
import { IAccessManagerFacet } from "rubic/Interfaces/IAccessManagerFacet.sol";
import { UnAuthorized, ZeroAddress } from "rubic/Errors/GenericErrors.sol";

contract CelerWithdrawFacetTest is TestBase {
    // These values are for Mainnet
    address internal constant CELER =
        0x5427FEFA711Eff984124bFBB1AB6fbf5E3DA1820;

    CelerWithdrawFacet.CelerData internal _celerData;

    CelerWithdrawFacet internal celerWithdrawFacet;

    function setUp() public {
        customBlockNumberForForking = 22022845;
        initTestBase();

        diamond = RubicMultiProxy(
            payable(0x6AA981bFF95eDfea36Bdae98C26B274FfcafE8d3)
        );

        vm.startPrank(0x00009cc27c811a3e0FdD2Fd737afCc721B67eE8e);

        celerWithdrawFacet = new CelerWithdrawFacet(ICelerWithdraw(CELER));

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = celerWithdrawFacet.withdrawFromCeler.selector;

        addFacet(diamond, address(celerWithdrawFacet), functionSelectors);

        setFacetAddressInTestBase(
            address(celerWithdrawFacet),
            "CelerWithdrawFacet"
        );

        celerWithdrawFacet = CelerWithdrawFacet(address(diamond));

        bytes[] memory _sigs = new bytes[](7);
        _sigs[
            0
        ] = hex"9aed97cb8b0ea5ae4e679b41dc0ac33cccee738e86e6eaf3818b3dd562a2383f44471d445c0d650378cb6560fdcd32c3bbf2b401a5523d0fa3a5390a358aaa8e1c";
        _sigs[
            1
        ] = hex"eb289f495352c83dbc78ce0105a5fe2ac96de8c6ad7acc4d1d65e5c70344f86638546f3e8b25d7ecc0fd4ab6d52e7e4b5b5d10c99b3a7aee241a3ec897a5aa0a1b";
        _sigs[
            2
        ] = hex"dc40ab91b071e15316c201f0e794619bf9b5b323bfaf37d66649a037d9afa4266e28074950a1c4962a31cccf1da0d995a5b055b5e5872a338445e173cfbc53b51c";
        _sigs[
            3
        ] = hex"e130699b86645a7b2de0c24e8d6dc1ea2cad783c4bf2e85f65ac801cec984a520dd1ffce8310e00aebb65d2d7eba675daba7e38eb7959ca0721ccd86e1ac420b1b";
        _sigs[
            4
        ] = hex"c9651e4e201289a770d57d65888d998502ee372ada9b9d026363d49381087ef26922f0867af524a0268bed0e0a2d3bf8acb88f446ef53e5bc3afd81cbad5631c1c";
        _sigs[
            5
        ] = hex"55b44febd3bc2ddd19f2770ca36faaac50c81f1054453992d966175fca12b2a959c5f51c464d86b6bfe5b143f6d468d6e855b9d998a1849b7da9f8f0f208815f1c";
        _sigs[
            6
        ] = hex"099fb37e0af4b9d28745dd1c89642828614b2898784b8206721c4e442af79fe53fd1dec6c68a11d847c65cb2c634fa287d9b4a7b3f322bda84b786962a9a6e8e1c";

        address[] memory _signers = new address[](20);
        _signers[0] = 0x241A100333EEfA2efC389Ec836A6fF619fC1c644;
        _signers[1] = 0x273035E10F106499efAce385DbA07135E7cC8E54;
        _signers[2] = 0x55f4A1BFc655cf55eD325F2338a1deE84f754Df2;
        _signers[3] = 0x57c96a00F9fF7B25CB5Cf964F1A191BE9321b8c8;
        _signers[4] = 0x870cF8Dd5d9C8eB1403dfd6e6A4753f4d617A538;
        _signers[5] = 0x95016E36Adb4e0151735Ced3992A7Fa54E16BD08;
        _signers[6] = 0x954ADc74481634b4d278C459853b4e6cc17aE8D2;
        _signers[7] = 0x98E9D288743839e96A8005a6B51C770Bbf7788C0;
        _signers[8] = 0x9a66644084108a1bC23A9cCd50d6d63E53098dB6;
        _signers[9] = 0x9a8CFAcF513fB3d5E39F5952C8608e985B3DC6eF;
        _signers[10] = 0x9AC5279013EdfEC74c5c2976FC831Ad0527402E0;
        _signers[11] = 0x9Cd5006e1BfF785dad5869efd81a2c42545C9d9b;
        _signers[12] = 0xa73B339c3fae27bedf7Cb72D9D000b08fc899609;
        _signers[13] = 0xbfa2F68bf9Ad60Dc3cFB1cEF04730Eb7FA251424;
        _signers[14] = 0xc74ACAb8C0a340f585d008cB521d64d2554171A8;
        _signers[15] = 0xcF12DD34d7597D06ff98F85d2B9483D9D5f7D952;
        _signers[16] = 0xd10c833f4305E1053a64Bc738c550381f48104Ca;
        _signers[17] = 0xF4151eEbFa1B9C87dD92c8243A18B1bAEf8C1813;
        _signers[18] = 0xF5AD7f3782E8A67BffA297684e27CF9fCC781Be1;
        _signers[19] = 0xF6e93Eb288658de5E2E982f99D2b378B22959d15;

        uint256[] memory _powers = new uint256[](20);
        _powers[0] = 57039103380000000000000000;
        _powers[1] = 82217501462780000000000000;
        _powers[2] = 44248953920000000000000000;
        _powers[3] = 100223544630000000000000000;
        _powers[4] = 99010000000000000000000000;
        _powers[5] = 30959434930000000000000000;
        _powers[6] = 52720591790000000000000000;
        _powers[7] = 279952529720000000000000000;
        _powers[8] = 320759656643902544900122309;
        _powers[9] = 74728937462460000000000000;
        _powers[10] = 69019069260000000000000000;
        _powers[11] = 307235959200000000000000000;
        _powers[12] = 6339601286097720000000000;
        _powers[13] = 244251080179141991500000000;
        _powers[14] = 175518746900000000000000000;
        _powers[15] = 72643396060000000000000000;
        _powers[16] = 167732134170000000000000000;
        _powers[17] = 81046074580000000000000000;
        _powers[18] = 60145824520000000000000000;
        _powers[19] = 26786734000000000000000000;

        _celerData = CelerWithdrawFacet.CelerData(
            hex"080110a183d0bd061a146aa981bff95edfea36bdae98c26b274ffcafe8d32214dac17f958d2ee523a2206206994597c13d831ec72a04046de09a32206053d1a3a4c9142edf4bbd7a8fea027ed98fd68b439961b26526401eeb8c7c08",
            _sigs,
            _signers,
            _powers
        );

        IAccessManagerFacet(address(diamond)).setCanExecute(
            celerWithdrawFacet.withdrawFromCeler.selector,
            USER_SENDER,
            true
        );

        vm.stopPrank();

        vm.startPrank(USER_SENDER);
    }

    function testRefund() public {
        celerWithdrawFacet.withdrawFromCeler(
            _celerData,
            ADDRESS_USDT,
            payable(address(0x228228228))
        );

        assertEq(usdt.balanceOf(address(0x228228228)), 74309786);
    }

    function testOwnerCanRefund() public {
        vm.stopPrank();
        vm.prank(0x00009cc27c811a3e0FdD2Fd737afCc721B67eE8e);

        celerWithdrawFacet.withdrawFromCeler(
            _celerData,
            ADDRESS_USDT,
            payable(address(0x228228228))
        );

        assertEq(usdt.balanceOf(address(0x228228228)), 74309786);

        vm.startPrank(USER_SENDER);
    }

    function test_Revert_Unauthorized() public {
        vm.stopPrank();
        vm.prank(0x00009cc27c811a3e0FdD2Fd737afCc721B67eE8e);

        IAccessManagerFacet(address(diamond)).setCanExecute(
            celerWithdrawFacet.withdrawFromCeler.selector,
            USER_SENDER,
            false
        );

        vm.startPrank(USER_SENDER);

        vm.expectRevert(UnAuthorized.selector);

        celerWithdrawFacet.withdrawFromCeler(
            _celerData,
            ADDRESS_USDT,
            payable(address(0x228228228))
        );
    }

    function test_Revert_CannotRefundToZeroUser() public {
        vm.expectRevert(ZeroAddress.selector);

        celerWithdrawFacet.withdrawFromCeler(
            _celerData,
            ADDRESS_USDT,
            payable(address(0))
        );
    }
}

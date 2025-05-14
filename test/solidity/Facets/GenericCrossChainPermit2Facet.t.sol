// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet } from "../utils/TestBaseFacet.sol";
import { TestToken } from "../utils/TestToken.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { IXSwapper } from "rubic/Interfaces/IXSwapper.sol";
import { LibMappings } from "rubic/Libraries/LibMappings.sol";
import { GenericCrossChainPermit2Facet } from "rubic/Facets/GenericCrossChainPermit2Facet.sol";
import { GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacet.sol";
import { UnAuthorized } from "src/Errors/GenericErrors.sol";

// Stub GenericCrossChainPermit2Facet Contract
contract TestGenericCrossChainFacet is
    GenericCrossChainPermit2Facet,
    TestFacet
{
    constructor()
        GenericCrossChainPermit2Facet(
            0x000000000022D473030F116dDEE9F6B43aC78BA3
        )
    {}
}

contract GenericCrossChainPermit2FacetTest is TestBaseFacet {
    address internal constant XSWAPPER =
        0x4315f344a905dC21a08189A117eFd6E1fcA37D57;
    address internal constant xyNativeAddress =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    TestGenericCrossChainFacet internal genericCrossChainFacet;
    TestToken internal testToken;
    GenericCrossChainFacet.GenericCrossChainData
        internal genericCrossChainData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            genericCrossChainFacet
                .startBridgeTokensViaGenericCrossChainPermit2
                .selector,
            bridgeData,
            genericCrossChainData
        );

        address[] memory tokens;
        uint256[] memory amounts;

        if (isNative) {
            erc20proxy.startViaRubic{
                value: bridgeData.minAmount + addToMessageValue
            }(tokens, amounts, facetCallData);
        } else {
            tokens = new address[](1);
            amounts = new uint256[](1);

            tokens[0] = bridgeData.sendingAssetId;
            amounts[0] = bridgeData.minAmount;

            erc20proxy.startViaRubic{ value: addToMessageValue }(
                tokens,
                amounts,
                facetCallData
            );
        }
    }

    function initiateSwapAndBridgeTxWithFacet(
        bool isNative
    ) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            genericCrossChainFacet
                .swapAndStartBridgeTokensViaGenericCrossChainPermit2
                .selector,
            bridgeData,
            swapData,
            genericCrossChainData
        );

        address[] memory tokens;
        uint256[] memory amounts;

        if (isNative) {
            erc20proxy.startViaRubic{
                value: swapData[0].fromAmount + addToMessageValue
            }(tokens, amounts, facetCallData);
        } else {
            if (swapData.length > 0) {
                tokens = new address[](1);
                amounts = new uint256[](1);
                tokens[0] = swapData[0].sendingAssetId;
                amounts[0] = swapData[0].fromAmount;
            }

            erc20proxy.startViaRubic{ value: addToMessageValue }(
                tokens,
                amounts,
                facetCallData
            );
        }
    }

    function setUp() public {
        initTestBase();

        genericCrossChainFacet = new TestGenericCrossChainFacet();
        GenericCrossChainFacet gcc = new GenericCrossChainFacet();
        testToken = new TestToken("Test", "TST", 18);

        testToken.mint(USER_SENDER, 10_000 ether);

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = genericCrossChainFacet
            .startBridgeTokensViaGenericCrossChainPermit2
            .selector;
        functionSelectors[1] = genericCrossChainFacet
            .swapAndStartBridgeTokensViaGenericCrossChainPermit2
            .selector;
        functionSelectors[2] = genericCrossChainFacet.addDex.selector;
        functionSelectors[3] = genericCrossChainFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(genericCrossChainFacet), functionSelectors);

        functionSelectors = new bytes4[](2);
        functionSelectors[0] = gcc.updateSelectorInfo.selector;
        functionSelectors[1] = gcc.getSelectorInfo.selector;

        addFacet(diamond, address(gcc), functionSelectors);

        genericCrossChainFacet = TestGenericCrossChainFacet(address(diamond));

        genericCrossChainFacet.addDex(address(uniswap));
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(
            address(genericCrossChainFacet),
            "GenericCrossChainFacet"
        );

        bridgeData.bridge = "generic_testProvider";
        bridgeData.minAmount = defaultUSDCAmount;

        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(0x5418226aF9C8d5D287A78FbBbCD337b86ec07D61),
            0x5418226aF9C8d5D287A78FbBbCD337b86ec07D61,
            0,
            hex"1fff991f000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000985e090e0426b800000000000000000000000000000000000000000000000000000000000000a0fe77207f9937b9f1b76b95220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000004e000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000440000000000000000000000000000000000000000000000000000000000000012438c9c147000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ad01c20d5886137e056775af56915de824c8fce50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c4103b48be0000000000000000000000005418226af9c8d5d287a78fbbbcd337b86ec07d61000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000027100000000000000000000000002e8135be71230c6b1b4045696d41c09db04142260000000000000000000000000000000000000000000000000000000000001901000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010438c9c147000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000002710000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000242e1a7d4d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064c876d21d000000000000000000000000f5c4f3dc02c3fb9279495a8fef7b0741da956157000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000000000000000000000000000009a445f547fd50e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffc1fb425e0000000000000000000000005418226af9c8d5d287a78fbbbcd337b86ec07d61000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000005f5e1000000000000000000000000000000000000006e898131631616b1779bad70bc1400000000000000000000000000000000000000000000000000000000681e1b6300000000000000000000000000000000000000000000000000000000000000c0"
        );

        address[] memory _routers = new address[](1);
        bytes4[] memory _selectors = new bytes4[](1);
        LibMappings.ProviderFunctionInfo[]
            memory _infos = new LibMappings.ProviderFunctionInfo[](1);

        _routers[0] = 0x5418226aF9C8d5D287A78FbBbCD337b86ec07D61;
        _selectors[0] = hex"1fff991f";
        _infos[0] = LibMappings.ProviderFunctionInfo(true, 0);

        GenericCrossChainFacet(address(diamond)).updateSelectorInfo(
            _routers,
            _selectors,
            _infos
        );
    }

    function testGetSelectorInfo() public {
        LibMappings.ProviderFunctionInfo memory info = GenericCrossChainFacet(
            address(diamond)
        ).getSelectorInfo(XSWAPPER, IXSwapper.swap.selector);

        assertEq(info.offset, 32 * 4 + 4);
    }

    function test_Revert_CannotUseNotAvailableProvider() public {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(address(this)),
            XSWAPPER,
            0,
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        bridgeData.sendingAssetId = address(0);
        bridgeData.minAmount = 1 ether;

        vm.expectRevert(UnAuthorized.selector);

        initiateBridgeTxWithFacet(true);
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        // amount should be greater than xy fee
        vm.assume(amount > 15);
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }

    function testBase_CanBridgeNativeTokens() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            XSWAPPER,
            0,
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanBridgeNativeTokens();
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            XSWAPPER,
            0,
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanBridgeNativeTokensWithFees();
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            XSWAPPER,
            0,
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanSwapAndBridgeNativeTokens();
    }
}

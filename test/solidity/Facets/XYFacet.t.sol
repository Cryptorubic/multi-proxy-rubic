// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet, console } from "../utils/TestBaseFacet.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { XYFacet } from "rubic/Facets/XYFacet.sol";
import { IXSwapper } from "rubic/Interfaces/IXSwapper.sol";

// Stub XYFacet Contract
contract TestXYFacet is XYFacet, TestFacet {
    constructor(IXSwapper _router) XYFacet(_router) {}
}

contract XYFacetTest is TestBaseFacet {
    // These values are for Mainnet
    address internal constant XSWAPPER =
        0x4315f344a905dC21a08189A117eFd6E1fcA37D57;

    TestXYFacet internal xyFacet;
    XYFacet.XYData internal xyData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            xyFacet.startBridgeTokensViaXY.selector,
            bridgeData,
            xyData
        );

        address[] memory tokens;
        uint256[] memory amounts;

        if (isNative) {
            erc20proxy.startCrossChain{
                value: bridgeData.minAmount + addToMessageValue
            }(tokens, amounts, facetCallData);
        } else {
            tokens = new address[](1);
            amounts = new uint256[](1);

            tokens[0] = bridgeData.sendingAssetId;
            amounts[0] = bridgeData.minAmount;

            erc20proxy.startCrossChain{ value: addToMessageValue }(
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
            xyFacet.swapAndStartBridgeTokensViaXY.selector,
            bridgeData,
            swapData,
            xyData
        );

        address[] memory tokens;
        uint256[] memory amounts;

        if (isNative) {
            erc20proxy.startCrossChain{
                value: swapData[0].fromAmount + addToMessageValue
            }(tokens, amounts, facetCallData);
        } else {
            if (swapData.length > 0) {
                tokens = new address[](1);
                amounts = new uint256[](1);
                tokens[0] = swapData[0].sendingAssetId;
                amounts[0] = swapData[0].fromAmount;
            }

            erc20proxy.startCrossChain{ value: addToMessageValue }(
                tokens,
                amounts,
                facetCallData
            );
        }
    }

    function setUp() public {
        initTestBase();

        xyFacet = new TestXYFacet(IXSwapper(XSWAPPER));

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = xyFacet.startBridgeTokensViaXY.selector;
        functionSelectors[1] = xyFacet.swapAndStartBridgeTokensViaXY.selector;
        functionSelectors[2] = xyFacet.addDex.selector;
        functionSelectors[3] = xyFacet.setFunctionApprovalBySignature.selector;

        addFacet(diamond, address(xyFacet), functionSelectors);

        xyFacet = TestXYFacet(address(diamond));

        xyFacet.addDex(address(uniswap));
        xyFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        xyFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        xyFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        xyFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(address(xyFacet), "XYFacet");

        bridgeData.bridge = "xy";
        bridgeData.minAmount = defaultUSDCAmount;

        xyData = XYFacet.XYData(
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            1000,
            100
        );
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        // amount should be greater than xy fee
        vm.assume(amount > 15);
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }
}

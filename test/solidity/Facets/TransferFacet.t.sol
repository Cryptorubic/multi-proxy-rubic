// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet } from "../utils/TestBaseFacet.sol";
import { TestToken } from "../utils/TestToken.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { TransferFacet } from "rubic/Facets/TransferFacet.sol";
import { IFeesFacet } from "rubic/Interfaces/IFeesFacet.sol";
import { UnAuthorized } from "src/Errors/GenericErrors.sol";

// Stub TransferFacet Contract
contract TestTransferFacet is TransferFacet, TestFacet {
    constructor() {}
}

contract TransferFacetTest is TestBaseFacet {
    address payable constant DESTINATION = payable(address(0xdedededede));

    TestTransferFacet internal transferFacet;
    TestToken internal testToken;
    TransferFacet.TransferData internal transferData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            transferFacet.startBridgeTokensViaTransfer.selector,
            bridgeData,
            transferData
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
            transferFacet.swapAndStartBridgeTokensViaTransfer.selector,
            bridgeData,
            swapData,
            transferData
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

        transferFacet = new TestTransferFacet();

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = transferFacet
            .startBridgeTokensViaTransfer
            .selector;
        functionSelectors[1] = transferFacet
            .swapAndStartBridgeTokensViaTransfer
            .selector;
        functionSelectors[2] = transferFacet.addDex.selector;
        functionSelectors[3] = transferFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(transferFacet), functionSelectors);

        transferFacet = TestTransferFacet(address(diamond));

        transferFacet.addDex(address(uniswap));
        transferFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        transferFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        transferFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        transferFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(address(transferFacet), "TransferFacet");

        bridgeData.bridge = "transfer";
        bridgeData.minAmount = defaultUSDCAmount;

        transferData = TransferFacet.TransferData(DESTINATION);
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        super.testBase_CanBridgeTokens_fuzzed(amount);

        assertEq(usdc.balanceOf(DESTINATION), amount * 10 ** usdc.decimals());
    }

    function testBase_CanBridgeTokens() public override {
        super.testBase_CanBridgeTokens();

        assertEq(usdc.balanceOf(DESTINATION), bridgeData.minAmount);
    }

    function testBase_CanBridgeTokensWithFees() public override {
        super.testBase_CanBridgeTokensWithFees();

        (uint256 totalFee, , ) = IFeesFacet(address(diamond)).calcTokenFees(
            bridgeData.minAmount,
            INTEGRATOR
        );
        assertEq(usdc.balanceOf(DESTINATION), bridgeData.minAmount - totalFee);
    }

    function testBase_CanBridgeNativeTokens() public override {
        super.testBase_CanBridgeNativeTokens();

        assertEq(DESTINATION.balance, bridgeData.minAmount);
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        super.testBase_CanBridgeNativeTokensWithFees();

        (uint256 totalFee, , ) = IFeesFacet(address(diamond)).calcTokenFees(
            bridgeData.minAmount,
            INTEGRATOR
        );
        assertEq(DESTINATION.balance, bridgeData.minAmount - totalFee);
    }

    function testBase_CanSwapAndBridgeTokens() public override {
        super.testBase_CanSwapAndBridgeTokens();

        assertEq(usdc.balanceOf(DESTINATION), defaultUSDCAmount);
    }

    function testBase_CanSwapAndBridgeTokensWithFees() public override {
        super.testBase_CanSwapAndBridgeTokensWithFees();

        assertEq(usdc.balanceOf(DESTINATION), defaultUSDCAmount);
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        super.testBase_CanSwapAndBridgeNativeTokens();

        assertEq(DESTINATION.balance, 1 ether);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet } from "../utils/TestBaseFacet.sol";
import { IRubic } from "rubic/Interfaces/IRubic.sol";
import { TestToken } from "../utils/TestToken.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { TransferAndCallFacet } from "rubic/Facets/TransferAndCallFacet.sol";
import { IFeesFacet } from "rubic/Interfaces/IFeesFacet.sol";
import { UnAuthorized } from "src/Errors/GenericErrors.sol";

// Stub TransferAndCallFacet Contract
contract TestTransferAndCallFacet is TransferAndCallFacet, TestFacet {
    constructor() {}
}

contract TransferAndCallFacetTest is TestBaseFacet {
    TestToken private constant PULSE_WETH =
        TestToken(0x97Ac4a2439A47c07ad535bb1188c989dae755341);
    address private constant DESTINATION =
        0x1715a3E4A142d8b698131108995174F37aEBA10D;

    uint256 constant DEFAULT_PULSE_AMOUNT = 100 ether;

    TestTransferAndCallFacet internal transferFacet;
    TransferAndCallFacet.TransferAndCallData internal transferAndCallData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            transferFacet.startBridgeTokensViaTransferAndCall.selector,
            bridgeData,
            transferAndCallData
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
            transferFacet.swapAndStartBridgeTokensViaTransferAndCall.selector,
            bridgeData,
            swapData,
            transferAndCallData
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
        customBlockNumberForForking = 18820931;

        initTestBase();

        transferFacet = new TestTransferAndCallFacet();

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = transferFacet
            .startBridgeTokensViaTransferAndCall
            .selector;
        functionSelectors[1] = transferFacet
            .swapAndStartBridgeTokensViaTransferAndCall
            .selector;
        functionSelectors[2] = transferFacet.addDex.selector;
        functionSelectors[3] = transferFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(transferFacet), functionSelectors);

        transferFacet = TestTransferAndCallFacet(address(diamond));

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

        setFacetAddressInTestBase(
            address(transferFacet),
            "TransferAndCallFacet"
        );

        deal(address(PULSE_WETH), USER_SENDER, 100_000 * 10 ** 18);

        vm.prank(USER_SENDER);
        PULSE_WETH.approve(address(erc20proxy), type(uint256).max);

        bridgeData.bridge = "transfer";
        bridgeData.sendingAssetId = address(PULSE_WETH);
        bridgeData.minAmount = DEFAULT_PULSE_AMOUNT;

        transferAndCallData = TransferAndCallFacet.TransferAndCallData(
            DESTINATION,
            abi.encodePacked(USER_SENDER)
        );
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        vm.startPrank(USER_SENDER);

        vm.assume(amount > 0 && amount < 100_000);
        amount = amount * 10 ** PULSE_WETH.decimals();

        // logFilePath = "./test/logs/"; // works but is not really a proper file
        // logFilePath = "./test/logs/fuzz_test.txt"; // throws error "failed to write to "....../test/logs/fuzz_test.txt": No such file or directory"
        logFilePath = string.concat(
            logFilePath,
            "fuzz_test_",
            facetName,
            ".txt"
        );

        vm.writeLine(logFilePath, vm.toString(amount));
        // approval
        PULSE_WETH.approve(address(erc20proxy), amount);

        bridgeData.sendingAssetId = address(PULSE_WETH);
        bridgeData.minAmount = amount;

        //        vm.expectEmit(true, true, true, true, address(PULSE_WETH));
        //        emit Transfer(DESTINATION, address(0), amount * 10 ** PULSE_WETH.decimals());

        initiateBridgeTxWithFacet(false);
        vm.stopPrank();
    }

    function testBase_CanBridgeTokens()
        public
        override
        assertBalanceChange(
            address(PULSE_WETH),
            USER_SENDER,
            -int256(DEFAULT_PULSE_AMOUNT)
        )
        assertBalanceChange(ADDRESS_USDC, USER_RECEIVER, 0)
        assertBalanceChange(ADDRESS_DAI, USER_SENDER, 0)
        assertBalanceChange(ADDRESS_DAI, USER_RECEIVER, 0)
    {
        vm.startPrank(USER_SENDER);

        //prepare check for events
        vm.expectEmit(true, true, true, true, _facetTestContractAddress);

        emit RubicTransferStarted(bridgeData);

        initiateBridgeTxWithFacet(false);
        vm.stopPrank();
    }

    function testBase_CanBridgeTokensWithFees()
        public
        override
        setIntegratorFee(DEFAULT_PULSE_AMOUNT)
        assertBalanceChange(
            address(PULSE_WETH),
            USER_SENDER,
            -int256(DEFAULT_PULSE_AMOUNT)
        )
        assertBalanceChange(
            address(PULSE_WETH),
            FEE_TREASURY,
            int256(rubicFeeTokenAmount)
        )
        assertBalanceChange(
            address(PULSE_WETH),
            INTEGRATOR,
            int256(integratorFeeTokenAmount)
        )
    {
        vm.startPrank(USER_SENDER);

        bridgeData.integrator = INTEGRATOR;
        //prepare check for events
        vm.expectEmit(true, true, true, true, _facetTestContractAddress);
        emit RubicTransferStarted(
            IRubic.BridgeData(
                bridgeData.transactionId,
                bridgeData.bridge,
                bridgeData.integrator,
                bridgeData.referrer,
                bridgeData.sendingAssetId,
                bridgeData.receivingAssetId,
                bridgeData.receiver,
                bridgeData.refundee,
                bridgeData.minAmount - feeTokenAmount,
                bridgeData.destinationChainId,
                bridgeData.hasSourceSwaps,
                bridgeData.hasDestinationCall
            )
        );

        initiateBridgeTxWithFacet(false);
        vm.stopPrank();
    }

    function testBase_CanBridgeNativeTokens() public override {
        // facet does not support native tokens
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        // facet does not support native tokens
    }

    function testBase_CanSwapAndBridgeTokens() public override {
        // cannot swap
    }

    function testBase_CanSwapAndBridgeTokensWithFees() public override {
        // cannot swap
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        // facet does not support native tokens
    }

    function testBase_Revert_CallerHasInsufficientFunds() public override {
        // token is broken
    }
}

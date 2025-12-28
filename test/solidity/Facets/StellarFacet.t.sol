// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet, console, RubicMultiProxy, IRubic } from "../utils/TestBaseFacet.sol";
import { OnlyContractOwner, InvalidConfig, AlreadyInitialized } from "rubic/Errors/GenericErrors.sol";
import { StellarFacet } from "rubic/Facets/StellarFacet.sol";
import { IAllBridgeCore } from "rubic/Interfaces/IAllBridgeCore.sol";
import { IAccessManagerFacet } from "rubic/Interfaces/IAccessManagerFacet.sol";
import { AlreadyInitialized, UnAuthorized } from "rubic/Errors/GenericErrors.sol";

// Stub CBridgeFacet Contract
contract TestStellarFacet is StellarFacet {
    /// @notice Initialize the contract.
    /// @param _allBridgeCore The contract address of the allbridge core contract on the source chain.
    constructor(address _allBridgeCore) StellarFacet(_allBridgeCore) {}

    function addDex(address _dex) external {
        LibAllowList.addAllowedContract(_dex);
    }

    function setFunctionApprovalBySignature(bytes4 _signature) external {
        LibAllowList.addAllowedSelector(_signature);
    }
}

contract StellarFacetTest is TestBaseFacet {
    // copy of Deposit event
    event Deposit(StellarFacet.DepositEventParams params);

    address internal constant ALLBRIDGE_CORE =
        0x609c690e8F7D68a59885c9132e812eEbDaAf0c9e;

    TestStellarFacet internal stellarFacet;
    StellarFacet.StellarData internal stellarData;

    function setUp() public {
        // set custom block number for forking
        customBlockNumberForForking = 24040000;

        initTestBase();

        stellarFacet = new TestStellarFacet(ALLBRIDGE_CORE);

        bytes4[] memory functionSelectors = new bytes4[](11);
        functionSelectors[0] = stellarFacet.initStellar.selector;
        functionSelectors[1] = stellarFacet
            .startBridgeTokensViaAllBridge
            .selector;
        functionSelectors[2] = stellarFacet
            .swapAndStartBridgeTokensViaAllBridge
            .selector;
        functionSelectors[3] = stellarFacet.setScalingFactor.selector;
        functionSelectors[4] = stellarFacet.setRelayerFeeReceiver.selector;
        functionSelectors[5] = stellarFacet.getNonces.selector;
        functionSelectors[6] = stellarFacet.getRelayerFeeReceiver.selector;
        functionSelectors[7] = stellarFacet.getScalingFactor.selector;
        functionSelectors[8] = stellarFacet.calculateRelayerFee.selector;
        functionSelectors[9] = stellarFacet.addDex.selector;
        functionSelectors[10] = stellarFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(stellarFacet), functionSelectors);

        IAccessManagerFacet(address(diamond)).setCanExecute(
            stellarFacet.initStellar.selector,
            address(this),
            true
        );

        IAccessManagerFacet(address(diamond)).setCanExecute(
            stellarFacet.setScalingFactor.selector,
            address(this),
            true
        );

        IAccessManagerFacet(address(diamond)).setCanExecute(
            stellarFacet.setRelayerFeeReceiver.selector,
            address(this),
            true
        );

        stellarFacet = TestStellarFacet(address(diamond));
        stellarFacet.initStellar(USER_RECEIVER, 5 * 10 ** 18);

        stellarFacet.addDex(address(uniswap));
        stellarFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        stellarFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        stellarFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );

        setFacetAddressInTestBase(address(stellarFacet), "StellarFacet");

        bridgeData.bridge = "stellar";
        bridgeData.minAmount = defaultUSDCAmount;
        bridgeData.destinationChainId = 7;

        stellarData = StellarFacet.StellarData({
            tokensOut: [
                bytes32(
                    0xadefce59aee52968f76061d494c2525b75659fa4296a65f499ef29e56477e496
                ),
                bytes32(0)
            ],
            amountOutMin: 0,
            finalReceiver: bytes32(uint256(0xabc)),
            allBridgeReceiver: bytes32(uint256(0xabc)),
            nonce: 0,
            destinationSwapDeadline: 0,
            allBridgeFee: IAllBridgeCore(ALLBRIDGE_CORE)
                .getBridgingCostInTokens(
                    7,
                    IAllBridgeCore.MessengerProtocol.Allbridge,
                    address(usdc)
                )
        });
    }

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            stellarFacet.startBridgeTokensViaAllBridge.selector,
            bridgeData,
            stellarData
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
            stellarFacet.swapAndStartBridgeTokensViaAllBridge.selector,
            bridgeData,
            swapData,
            stellarData
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

    function testBase_CanBridgeNativeTokens() public override {
        // facet does not support native bridging
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        // facet does not support native bridging
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        // facet does not support native bridging
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        vm.assume(amount > 2); // to cover allbridge fees
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }

    function test_DepositEventNoSwapNoDestSwap() public {
        vm.startPrank(USER_SENDER);
        usdc.approve(address(erc20proxy), bridgeData.minAmount);

        vm.expectEmit(true, true, true, true, _facetTestContractAddress);
        emit Deposit(
            StellarFacet.DepositEventParams(
                bridgeData.transactionId,
                bridgeData.integrator,
                bridgeData.sendingAssetId,
                bridgeData.minAmount,
                bridgeData.sendingAssetId,
                bridgeData.minAmount,
                stellarData.tokensOut[0],
                stellarData.tokensOut[1],
                stellarData.amountOutMin,
                stellarData.finalReceiver,
                stellarData.allBridgeReceiver,
                stellarData.allBridgeFee,
                bridgeData.destinationChainId,
                stellarData.nonce,
                stellarData.destinationSwapDeadline
            )
        );

        initiateBridgeTxWithFacet(false);
    }

    function test_DepositEventNoSwapDestSwap()
        public
        assertBalanceChange(
            address(usdc),
            stellarFacet.getRelayerFeeReceiver(),
            int256(stellarData.allBridgeFee * 5)
        )
    {
        stellarData.finalReceiver = bytes32(0);
        bridgeData.hasDestinationCall = true;

        vm.startPrank(USER_SENDER);
        usdc.approve(address(erc20proxy), bridgeData.minAmount);

        vm.expectEmit(true, true, true, true, _facetTestContractAddress);
        emit Deposit(
            StellarFacet.DepositEventParams(
                bridgeData.transactionId,
                bridgeData.integrator,
                bridgeData.sendingAssetId,
                bridgeData.minAmount - stellarData.allBridgeFee * 5,
                bridgeData.sendingAssetId,
                bridgeData.minAmount - stellarData.allBridgeFee * 5,
                stellarData.tokensOut[0],
                stellarData.tokensOut[1],
                stellarData.amountOutMin,
                stellarData.finalReceiver,
                stellarData.allBridgeReceiver,
                stellarData.allBridgeFee,
                bridgeData.destinationChainId,
                stellarData.nonce,
                stellarData.destinationSwapDeadline
            )
        );

        initiateBridgeTxWithFacet(false);
    }

    function test_DepositEventSwapNoDestSwap() public {
        bridgeData.hasSourceSwaps = true;
        _setDefaultSwapDataSingleDAItoUSDC(false);

        vm.startPrank(USER_SENDER);
        dai.approve(address(erc20proxy), swapData[0].fromAmount);

        vm.expectEmit(true, true, true, true, _facetTestContractAddress);
        emit Deposit(
            StellarFacet.DepositEventParams(
                bridgeData.transactionId,
                bridgeData.integrator,
                address(dai),
                swapData[0].fromAmount,
                bridgeData.sendingAssetId,
                bridgeData.minAmount,
                stellarData.tokensOut[0],
                stellarData.tokensOut[1],
                stellarData.amountOutMin,
                stellarData.finalReceiver,
                stellarData.allBridgeReceiver,
                stellarData.allBridgeFee,
                bridgeData.destinationChainId,
                stellarData.nonce,
                stellarData.destinationSwapDeadline
            )
        );

        initiateSwapAndBridgeTxWithFacet(false);
    }

    function test_DepositEventSwapDestSwap()
        public
        assertBalanceChange(
            address(usdc),
            stellarFacet.getRelayerFeeReceiver(),
            int256(stellarData.allBridgeFee * 5)
        )
    {
        bridgeData.hasSourceSwaps = true;
        stellarData.finalReceiver = bytes32(0);
        bridgeData.hasDestinationCall = true;
        _setDefaultSwapDataSingleDAItoUSDC(false);

        vm.startPrank(USER_SENDER);
        dai.approve(address(erc20proxy), swapData[0].fromAmount);

        vm.expectEmit(true, true, true, true, _facetTestContractAddress);
        emit Deposit(
            StellarFacet.DepositEventParams(
                bridgeData.transactionId,
                bridgeData.integrator,
                address(dai),
                swapData[0].fromAmount,
                bridgeData.sendingAssetId,
                bridgeData.minAmount - stellarData.allBridgeFee * 5,
                stellarData.tokensOut[0],
                stellarData.tokensOut[1],
                stellarData.amountOutMin,
                stellarData.finalReceiver,
                stellarData.allBridgeReceiver,
                stellarData.allBridgeFee,
                bridgeData.destinationChainId,
                stellarData.nonce,
                stellarData.destinationSwapDeadline
            )
        );

        initiateSwapAndBridgeTxWithFacet(false);
    }

    function test_Revert_InitOwnable() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        stellarFacet.initStellar(USER_RECEIVER, 5 * 10 ** 18);
    }

    function test_Revert_SetScalingFactorOwnable() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        stellarFacet.setScalingFactor(5 * 10 ** 18);
    }

    function test_Revert_SetRelayerFeeReceiverOwnable() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        stellarFacet.setRelayerFeeReceiver(USER_RECEIVER);
    }

    function test_Revert_InitTwice() public {
        vm.expectRevert(AlreadyInitialized.selector);
        stellarFacet.initStellar(USER_RECEIVER, 5 * 10 ** 18);
    }

    function test_Revert_DepositTwice() public {
        assertEq(stellarFacet.getNonces(0), false);

        vm.startPrank(USER_SENDER);
        usdc.approve(address(erc20proxy), bridgeData.minAmount);
        initiateBridgeTxWithFacet(false);

        assertEq(stellarFacet.getNonces(0), true);

        usdc.approve(address(erc20proxy), bridgeData.minAmount);
        vm.expectRevert(
            abi.encodeWithSelector(StellarFacet.UsedNonce.selector, 0)
        );
        initiateBridgeTxWithFacet(false);
    }

    function test_CalculateRelayerFee() public {
        assertEq(stellarFacet.getScalingFactor(), 5 * 10 ** 18);
        assertEq(
            stellarFacet.calculateRelayerFee(address(usdc)),
            stellarData.allBridgeFee * 5
        );
        stellarFacet.setScalingFactor(10 ** 17);
        assertEq(stellarFacet.getScalingFactor(), 10 ** 17);
        assertEq(
            stellarFacet.calculateRelayerFee(address(usdc)),
            stellarData.allBridgeFee / 10
        );
    }

    function test_SetRelayerFeeReceiver() public {
        assertEq(stellarFacet.getRelayerFeeReceiver(), USER_RECEIVER);
        stellarFacet.setRelayerFeeReceiver(USER_SENDER);
        assertEq(stellarFacet.getRelayerFeeReceiver(), USER_SENDER);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet, console, RubicMultiProxy } from "../utils/TestBaseFacet.sol";
import { OnlyContractOwner, AlreadyInitialized } from "src/Errors/GenericErrors.sol";
import { StargateFacet } from "rubic/Facets/StargateFacet.sol";
import { IStargateRouter } from "rubic/Interfaces/IStargateRouter.sol";

import "forge-std/console.sol";

// Stub CBridgeFacet Contract
contract TestStargateFacet is StargateFacet {
    /// @notice Initialize the contract.
    /// @param _router The contract address of the stargate router on the source chain.
    /// @param _nativeRouter The contract address of the native token stargate router on the source chain.
    constructor(
        IStargateRouter _router,
        IStargateRouter _nativeRouter,
        IStargateRouter _composer
    ) StargateFacet(_router, _nativeRouter, _composer) {}

    function addDex(address _dex) external {
        LibAllowList.addAllowedContract(_dex);
    }

    function setFunctionApprovalBySignature(bytes4 _signature) external {
        LibAllowList.addAllowedSelector(_signature);
    }
}

contract StargateFacetTest is TestBaseFacet {
    // EVENTS
    event LayerZeroChainIdSet(
        uint256 indexed chainId,
        uint16 layerZeroChainId
    );

    // These values are for Mainnet
    address internal constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant MAINNET_ROUTER =
        0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    address internal constant MAINNET_NATIVE_ROUTER =
        0xb1b2eeF380f21747944f46d28f683cD1FBB4d03c;
    address internal constant MAINNET_COMPOSER =
        0x3b83D454A50aBe06d94cb0d5d367825e190bDA8F;
    uint256 internal constant DST_CHAIN_ID = 10;
    // -----

    TestStargateFacet internal stargateFacet;
    StargateFacet.StargateData internal stargateData;

    function setUp() public {
        // set custom block number for forking
        customBlockNumberForForking = 18349720;

        initTestBase();

        stargateFacet = new TestStargateFacet(
            IStargateRouter(MAINNET_ROUTER),
            IStargateRouter(MAINNET_NATIVE_ROUTER),
            IStargateRouter(MAINNET_COMPOSER)
        );

        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = stargateFacet.initStargate.selector;
        functionSelectors[1] = stargateFacet
            .startBridgeTokensViaStargate
            .selector;
        functionSelectors[2] = stargateFacet
            .swapAndStartBridgeTokensViaStargate
            .selector;
        functionSelectors[3] = stargateFacet.setLayerZeroChainId.selector;
        functionSelectors[5] = stargateFacet.quoteLayerZeroFee.selector;
        functionSelectors[6] = stargateFacet.addDex.selector;
        functionSelectors[7] = stargateFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(stargateFacet), functionSelectors);

        StargateFacet.ChainIdConfig[]
            memory chainIdConfig = new StargateFacet.ChainIdConfig[](2);

        chainIdConfig[0] = StargateFacet.ChainIdConfig(1, 101);
        chainIdConfig[1] = StargateFacet.ChainIdConfig(10, 111);

        stargateFacet = TestStargateFacet(address(diamond));
        stargateFacet.initStargate(chainIdConfig);

        stargateFacet.addDex(address(uniswap));
        stargateFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        stargateFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        stargateFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        stargateFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(address(stargateFacet), "StargateFacet");

        bridgeData.bridge = "stargate";
        // set dst chain to Optimism for the ability
        // to bridge ETH
        bridgeData.destinationChainId = 10;
        bridgeData.minAmount = defaultUSDCAmount;

        stargateData = StargateFacet.StargateData({
            srcPoolId: 1,
            dstPoolId: 1,
            minAmountLD: (defaultUSDCAmount * 90) / 100,
            dstGasForCall: 0,
            lzFee: 0,
            refundAddress: payable(USER_REFUND),
            callTo: abi.encodePacked(address(0)),
            callData: ""
        });
        (uint256 fees, ) = stargateFacet.quoteLayerZeroFee(
            DST_CHAIN_ID,
            stargateData
        );

        stargateData.lzFee = addToMessageValue = fees;
    }

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        bytes memory facetCallData = abi.encodeWithSelector(
            stargateFacet.startBridgeTokensViaStargate.selector,
            bridgeData,
            stargateData
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
            stargateFacet.swapAndStartBridgeTokensViaStargate.selector,
            bridgeData,
            swapData,
            stargateData
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

    //    function testBase_CanBridgeNativeTokens() public override {
    //        // facet does not support native bridging
    //    }
    //
    //    function testBase_CanBridgeNativeTokensWithFees() public override {
    //        // facet does not support native bridging
    //    }
    //
    //    function testBase_CanSwapAndBridgeNativeTokens() public override {
    //        // facet does not support native bridging
    //    }

    function test_revert_SetLayerZeroChainIdAsNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(OnlyContractOwner.selector);
        stargateFacet.setLayerZeroChainId(123, 456);
    }

    function test_SetLayerZeroChainIdAsOwner() public {
        vm.startPrank(USER_DIAMOND_OWNER);
        vm.expectEmit(true, true, true, true, address(stargateFacet));
        emit LayerZeroChainIdSet(123, 456);
        stargateFacet.setLayerZeroChainId(123, 456);
    }

    function test_revert_InitializeAgain() public {
        vm.startPrank(USER_DIAMOND_OWNER);

        StargateFacet.ChainIdConfig[]
            memory chainIdConfig = new StargateFacet.ChainIdConfig[](2);
        chainIdConfig[0] = StargateFacet.ChainIdConfig(1, 101);
        chainIdConfig[1] = StargateFacet.ChainIdConfig(137, 109);

        vm.expectRevert(AlreadyInitialized.selector);
        stargateFacet.initStargate(chainIdConfig);
    }

    function test_revert_InitializeAsNonOwner() public {
        (RubicMultiProxy diamond2, ) = createDiamond(
            FEE_TREASURY,
            MAX_TOKEN_FEE
        );
        stargateFacet = new TestStargateFacet(
            IStargateRouter(MAINNET_ROUTER),
            IStargateRouter(MAINNET_ROUTER),
            IStargateRouter(MAINNET_ROUTER)
        );

        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = stargateFacet.initStargate.selector;
        functionSelectors[1] = stargateFacet
            .startBridgeTokensViaStargate
            .selector;
        functionSelectors[2] = stargateFacet
            .swapAndStartBridgeTokensViaStargate
            .selector;
        functionSelectors[3] = stargateFacet.setLayerZeroChainId.selector;
        functionSelectors[5] = stargateFacet.quoteLayerZeroFee.selector;
        functionSelectors[6] = stargateFacet.addDex.selector;
        functionSelectors[7] = stargateFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond2, address(stargateFacet), functionSelectors);

        StargateFacet.ChainIdConfig[]
            memory chainIdConfig = new StargateFacet.ChainIdConfig[](2);
        chainIdConfig[0] = StargateFacet.ChainIdConfig(1, 101);
        chainIdConfig[1] = StargateFacet.ChainIdConfig(137, 109);

        stargateFacet = TestStargateFacet(address(diamond2));

        vm.startPrank(USER_SENDER);

        vm.expectRevert(OnlyContractOwner.selector);
        stargateFacet.initStargate(chainIdConfig);
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        // fails otherwise with "slippage too high" from Stargate router contract
        vm.assume(amount > 100);
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }
}

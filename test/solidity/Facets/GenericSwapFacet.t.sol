// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { DSTest } from "ds-test/test.sol";
import { console } from "../utils/Console.sol";
import { TestBase, RubicMultiProxy } from "../utils/TestBase.sol";
import { Vm } from "forge-std/Vm.sol";
import { GenericSwapFacet } from "rubic/Facets/GenericSwapFacet.sol";
import { LibSwap } from "rubic/Libraries/LibSwap.sol";
import { LibAllowList } from "rubic/Libraries/LibAllowList.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { UniswapV2Router02 } from "../utils/Interfaces.sol";
import { IFeesFacet } from "rubic/Interfaces/IFeesFacet.sol";

// Stub GenericSwapFacet Contract
contract TestGenericSwapFacet is GenericSwapFacet {
    function addDex(address _dex) external {
        LibAllowList.addAllowedContract(_dex);
    }

    function setFunctionApprovalBySignature(bytes4 _signature) external {
        LibAllowList.addAllowedSelector(_signature);
    }
}

contract GenericSwapFacetTest is DSTest, TestBase {
    // These values are for Mainnet
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDC_HOLDER = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // -----

    TestGenericSwapFacet internal genericSwapFacet;

    function fork() internal override {
        string memory rpcUrl = vm.envString("ETH_NODE_URI_MAINNET");
        uint256 blockNumber = 15588208;
        vm.createSelectFork(rpcUrl, blockNumber);
    }

    function setUp() public {
        initTestBase();

        genericSwapFacet = new TestGenericSwapFacet();

        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = genericSwapFacet.swapTokensGeneric.selector;
        functionSelectors[1] = genericSwapFacet.addDex.selector;
        functionSelectors[2] = genericSwapFacet.setFunctionApprovalBySignature.selector;

        addFacet(diamond, address(genericSwapFacet), functionSelectors);

        genericSwapFacet = TestGenericSwapFacet(address(diamond));
        genericSwapFacet.addDex(address(uniswap));
        genericSwapFacet.setFunctionApprovalBySignature(uniswap.swapExactTokensForTokens.selector);
        genericSwapFacet.setFunctionApprovalBySignature(uniswap.swapExactETHForTokens.selector);
        genericSwapFacet.setFunctionApprovalBySignature(uniswap.swapExactTokensForETH.selector);

    }

    modifier setFees(){
        IFeesFacet(address(diamond)).setFixedNativeFee(1 ether);
        IFeesFacet(address(diamond)).setIntegratorInfo(USDC_HOLDER, IFeesFacet.IntegratorFeeInfo({
            isIntegrator: true,
            tokenFee: TOKEN_FEE,
            RubicTokenShare: 0,
            RubicFixedCryptoShare: 0,
            fixedFeeAmount: 0
        }));
        _;
    }

    function testCanSwapERC20() public {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(address(genericSwapFacet), 10_000 * 10**usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = USDC_ADDRESS;
        path[1] = DAI_ADDRESS;

        uint256 amountOut = 10 * 10**dai.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            USDC_ADDRESS,
            DAI_ADDRESS,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }

    function testCanSwapNativeToERC20() public {
        vm.startPrank(USDC_HOLDER);
        // Swap ETH to DAI
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = DAI_ADDRESS;

        uint256 amountOut = 10 * 10**dai.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            address(0),
            DAI_ADDRESS,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactETHForTokens.selector,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{value: amountIn}("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }

    function testCanSwapERC20ToNative() public {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(address(genericSwapFacet), 13_000 * 10**usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = USDC_ADDRESS;
        path[1] = WETH_ADDRESS;

        uint256 amountOut = 10 * 10**weth.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            USDC_ADDRESS,
            address(0),
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForETH.selector,
                amountIn,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }

    function testCanSwapERC20WithFees() public setFees {

        vm.startPrank(USDC_HOLDER);

        usdc.approve(address(genericSwapFacet), 10_000 * 10**usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = USDC_ADDRESS;
        path[1] = DAI_ADDRESS;

        uint256 amountOut = 10 * 10**dai.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = amountIn * ( DENOMINATOR + TOKEN_FEE) / DENOMINATOR;
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            USDC_ADDRESS,
            DAI_ADDRESS,
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{value: 1 ether}("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }

    function testCanSwapNativeToERC20WithFees() public setFees {
        vm.startPrank(USDC_HOLDER);
        // Swap ETH to DAI
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = DAI_ADDRESS;

        uint256 amountOut = 10 * 10**dai.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = amountIn * ( DENOMINATOR + TOKEN_FEE) / DENOMINATOR;
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            address(0),
            DAI_ADDRESS,
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactETHForTokens.selector,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{value: amountInWithFee + 1 ether}("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }

    function testCanSwapERC20ToNativeWithFees() public setFees {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(address(genericSwapFacet), 30_000 * 10**usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = USDC_ADDRESS;
        path[1] = WETH_ADDRESS;

        uint256 amountOut = 10 * 10**weth.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = amountIn * ( DENOMINATOR + TOKEN_FEE) / DENOMINATOR;

        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            USDC_ADDRESS,
            address(0),
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForETH.selector,
                amountIn,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{value: 1 ether}("", address(0), address(0), payable(USDC_HOLDER), amountOut, swapData);
        vm.stopPrank();
    }
}

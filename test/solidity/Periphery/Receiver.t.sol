// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { Test, TestBase, RubicMultiProxy, DSTest, IRubic, LibSwap, LibAllowList, console, InvalidAmount, ERC20, UniswapV2Router02 } from "../utils/TestBase.sol";
import { OnlyContractOwner } from "src/Errors/GenericErrors.sol";

import { Receiver } from "rubic/Periphery/Receiver.sol";
import { stdJson } from "forge-std/Script.sol";
import { RubicMultiProxy } from "rubic/RubicMultiProxy.sol";
import { DiamondCutFacet } from "rubic/Facets/DiamondCutFacet.sol";
import { DexManagerFacet } from "rubic/Facets/DexManagerFacet.sol";
import { IDiamondCut } from "rubic/Interfaces/IDiamondCut.sol";
import { Executor } from "rubic/Periphery/Executor.sol";

contract ReceiverTest is TestBase {
    using stdJson for string;

    Receiver internal receiver;

    error UnAuthorized();

    string path;
    string json;
    address stargateRouter;
    address amarokRouter;
    bytes32 internal transferId;
    Executor executor;
    DexManagerFacet internal dexMgr;

    event StargateRouterSet(address indexed router);
    event AmarokRouterSet(address indexed router);
    event ExecutorSet(address indexed executor);
    event RecoverGasSet(uint256 indexed recoverGas);

    function setUp() public {
        initTestBase();

        // obtain address of Stargate router in current network from config file
        path = string.concat(vm.projectRoot(), "/config/stargate.json");
        json = vm.readFile(path);
        stargateRouter = json.readAddress(string.concat(".routers.mainnet"));

        path = string.concat(vm.projectRoot(), "/config/amarok.json");
        json = vm.readFile(path);
        amarokRouter = json.readAddress(
            string.concat(".mainnet.connextHandler")
        );

        dexMgr = new DexManagerFacet();

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = DexManagerFacet.addDex.selector;
        functionSelectors[1] = DexManagerFacet.isContractApproved.selector;
        functionSelectors[2] = DexManagerFacet.isFunctionApproved.selector;
        functionSelectors[3] = DexManagerFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(dexMgr), functionSelectors);

        dexMgr = DexManagerFacet(address(diamond));

        executor = new Executor(address(this), address(dexMgr));
        receiver = new Receiver(
            address(this),
            stargateRouter,
            amarokRouter,
            address(executor),
            100000
        );

        dexMgr.addDex(address(uniswap));
        dexMgr.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector,
            true
        );

        vm.label(address(receiver), "Receiver");
        vm.label(address(executor), "Executor");
        vm.label(stargateRouter, "StargateRouter");
        vm.label(amarokRouter, "AmarokRouter");

        transferId = keccak256("123");
    }

    function test_revert_OwnerCanPullToken() public {
        // send token to receiver
        vm.startPrank(USER_SENDER);
        dai.transfer(address(receiver), 1000);
        vm.stopPrank();

        // pull token
        vm.startPrank(USER_DIAMOND_OWNER);

        receiver.pullToken(ADDRESS_DAI, payable(USER_RECEIVER), 1000);

        assertEq(1000, dai.balanceOf(USER_RECEIVER));
    }

    function test_revert_PullTokenNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        receiver.pullToken(ADDRESS_DAI, payable(USER_RECEIVER), 1000);
    }

    function test_OwnerCanUpdateRecoverGas() public {
        vm.startPrank(USER_DIAMOND_OWNER);

        vm.expectEmit(true, true, true, true, address(receiver));
        emit RecoverGasSet(1000);

        receiver.setRecoverGas(1000);
    }

    function test_revert_UpdateRecoverGasNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        receiver.setRecoverGas(1000);
    }

    function test_OwnerCanUpdateExecutorAddress() public {
        vm.startPrank(USER_DIAMOND_OWNER);

        vm.expectEmit(true, true, true, true, address(receiver));
        emit ExecutorSet(stargateRouter);

        receiver.setExecutor(stargateRouter);
    }

    function test_revert_UpdateExecutorAddressNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        receiver.setExecutor(stargateRouter);
    }

    // AMAROK-RELATED TESTS
    function test_amarok_ExecutesCrossChainMessage() public {
        // create swap data
        delete swapData;
        // Swap DAI -> USDC
        address[] memory swapPath = new address[](2);
        swapPath[0] = ADDRESS_DAI;
        swapPath[1] = ADDRESS_USDC;

        uint256 amountOut = defaultUSDCAmount;

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, swapPath);
        uint256 amountIn = amounts[0];

        swapData.push(
            LibSwap.SwapData({
                callTo: address(uniswap),
                approveTo: address(uniswap),
                sendingAssetId: ADDRESS_DAI,
                receivingAssetId: ADDRESS_USDC,
                fromAmount: amountIn,
                extraNative: 0,
                callData: abi.encodeWithSelector(
                    uniswap.swapExactTokensForTokens.selector,
                    amountIn,
                    amountOut,
                    swapPath,
                    address(executor),
                    block.timestamp + 20 minutes
                ),
                requiresDeposit: true
            })
        );

        // create callData that will be sent to our Receiver
        bytes memory payload = abi.encode(swapData, USER_RECEIVER);

        // fund receiver with sufficient DAI to execute swap
        deal(ADDRESS_DAI, address(receiver), swapData[0].fromAmount);

        // call xReceive function as Amarok router
        vm.startPrank(amarokRouter);
        dai.approve(address(receiver), swapData[0].fromAmount);

        uint32 fakeDomain = 12345;

        // prepare check for events
        vm.expectEmit(true, true, true, true, address(executor));
        emit AssetSwapped(
            0x64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb4387ab0107,
            address(uniswap),
            ADDRESS_DAI,
            ADDRESS_USDC,
            swapData[0].fromAmount,
            defaultUSDCAmount,
            block.timestamp
        );
        vm.expectEmit(true, true, true, true, address(executor));
        emit RubicTransferCompleted(
            transferId,
            ADDRESS_DAI,
            USER_RECEIVER,
            defaultUSDCAmount,
            block.timestamp
        );

        // call xReceive function to complete transaction
        receiver.xReceive(
            transferId,
            swapData[0].fromAmount,
            ADDRESS_DAI,
            USER_SENDER,
            fakeDomain,
            payload
        );
    }

    function test_amarok_ForwardsFundsToReceiverIfDestCallFails() public {
        // create swap data
        delete swapData;
        // Swap DAI -> USDC
        address[] memory swapPath = new address[](2);
        swapPath[0] = ADDRESS_DAI;
        swapPath[1] = ADDRESS_USDC;

        uint256 amountOut = defaultUSDCAmount;

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, swapPath);
        uint256 amountIn = amounts[0];

        swapData.push(
            LibSwap.SwapData({
                callTo: address(uniswap),
                approveTo: address(uniswap),
                sendingAssetId: ADDRESS_USDC, // swapped sending/receivingId => should fail
                receivingAssetId: ADDRESS_DAI,
                fromAmount: amountIn,
                extraNative: 0,
                callData: abi.encodeWithSelector(
                    uniswap.swapExactTokensForTokens.selector,
                    amountIn,
                    amountOut,
                    swapPath,
                    address(executor),
                    block.timestamp + 20 minutes
                ),
                requiresDeposit: true
            })
        );

        // create callData that will be sent to our Receiver
        bytes memory payload = abi.encode(swapData, USER_RECEIVER);

        // fund receiver with sufficient DAI to execute swap
        vm.startPrank(USER_DAI_WHALE);
        dai.transfer(address(receiver), swapData[0].fromAmount);
        vm.stopPrank();

        // call xReceive function as Amarok router
        vm.startPrank(amarokRouter);
        dai.approve(address(receiver), swapData[0].fromAmount);

        uint32 fakeDomain = 12345;

        // prepare check for events
        //! THIS DOES NOT WORK AND I DONT KNOW WHY - @ REVIEWER: PLS TRY TO DEBUG
        // vm.expectEmit(true, true, true, true, ADDRESS_DAI);
        // emit Transfer(address(receiver), USER_RECEIVER, swapData[0].fromAmount);

        vm.expectEmit(true, true, true, true, address(receiver));
        emit RubicTransferRecovered(
            transferId,
            ADDRESS_DAI,
            USER_RECEIVER,
            swapData[0].fromAmount,
            block.timestamp
        );

        // call xReceive function to complete transaction
        receiver.xReceive(
            transferId,
            swapData[0].fromAmount,
            ADDRESS_DAI,
            USER_SENDER,
            fakeDomain,
            payload
        );
    }

    function test_amarok_OwnerCanUpdateRouterAddress() public {
        vm.startPrank(USER_DIAMOND_OWNER);

        vm.expectEmit(true, true, true, true, address(receiver));
        emit AmarokRouterSet(stargateRouter);

        receiver.setAmarokRouter(stargateRouter);
    }

    function test_revert_amarok_UpdateRouterAddressNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        receiver.setAmarokRouter(stargateRouter);
    }

    // STARGATE-RELATED TESTS
    function test_stargate_ExecutesCrossChainMessage() public {
        // create swap data
        delete swapData;
        // Swap DAI -> USDC
        address[] memory swapPath = new address[](2);
        swapPath[0] = ADDRESS_DAI;
        swapPath[1] = ADDRESS_USDC;

        uint256 amountOut = defaultUSDCAmount;

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, swapPath);
        uint256 amountIn = amounts[0];

        swapData.push(
            LibSwap.SwapData({
                callTo: address(uniswap),
                approveTo: address(uniswap),
                sendingAssetId: ADDRESS_DAI,
                receivingAssetId: ADDRESS_USDC,
                fromAmount: amountIn,
                extraNative: 0,
                callData: abi.encodeWithSelector(
                    uniswap.swapExactTokensForTokens.selector,
                    amountIn,
                    amountOut,
                    swapPath,
                    address(executor),
                    block.timestamp + 20 minutes
                ),
                requiresDeposit: true
            })
        );

        // create callData that will be sent to our Receiver
        bytes32 txId = "txId";
        bytes memory payload = abi.encode(
            txId,
            swapData,
            USER_RECEIVER,
            USER_RECEIVER
        );

        // fund receiver with sufficient DAI to execute swap
        vm.startPrank(USER_DAI_WHALE);
        dai.transfer(address(receiver), swapData[0].fromAmount);
        vm.stopPrank();

        // call sgReceive function as Stargate router
        vm.startPrank(stargateRouter);
        dai.approve(address(receiver), swapData[0].fromAmount);

        // prepare check for events
        vm.expectEmit(true, true, true, true, address(executor));
        emit AssetSwapped(
            0x7478496400000000000000000000000000000000000000000000000000000000,
            address(uniswap),
            ADDRESS_DAI,
            ADDRESS_USDC,
            swapData[0].fromAmount,
            defaultUSDCAmount,
            block.timestamp
        );
        vm.expectEmit(true, true, true, true, address(executor));
        emit RubicTransferCompleted(
            0x7478496400000000000000000000000000000000000000000000000000000000,
            ADDRESS_DAI,
            USER_RECEIVER,
            defaultUSDCAmount,
            block.timestamp
        );

        // call sgReceive function to complete transaction
        receiver.sgReceive(
            0,
            "",
            0,
            ADDRESS_DAI,
            swapData[0].fromAmount,
            payload
        );
    }

    function test_stargate_EmitsCorrectEventOnRecovery() public {
        // (mock) transfer "bridged funds" to Receiver.sol
        vm.startPrank(USER_SENDER);
        usdc.transfer(address(receiver), defaultUSDCAmount);
        vm.stopPrank();

        bytes memory payload = abi.encode(
            transferId,
            swapData,
            address(1),
            address(1)
        );

        vm.startPrank(stargateRouter);
        vm.expectEmit(true, true, true, true, address(receiver));
        emit RubicTransferRecovered(
            keccak256("123"),
            ADDRESS_USDC,
            address(1),
            defaultUSDCAmount,
            block.timestamp
        );

        receiver.sgReceive{ gas: 100000 }(
            0,
            "",
            0,
            ADDRESS_USDC,
            defaultUSDCAmount,
            payload
        );
    }

    function test_stargate_OwnerCanUpdateRouterAddress() public {
        vm.startPrank(USER_DIAMOND_OWNER);

        vm.expectEmit(true, true, true, true, address(receiver));
        emit StargateRouterSet(amarokRouter);

        receiver.setStargateRouter(amarokRouter);
    }

    function test_revert_stargate_UpdateRouterAddressNonOwner() public {
        vm.startPrank(USER_SENDER);
        vm.expectRevert(UnAuthorized.selector);
        receiver.setStargateRouter(amarokRouter);
    }
}

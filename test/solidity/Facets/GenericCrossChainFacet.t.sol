// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet } from "../utils/TestBaseFacet.sol";
import { TestToken } from "../utils/TestToken.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { IXSwapper } from "rubic/Interfaces/IXSwapper.sol";
import { IAccessManagerFacet } from "rubic/Interfaces/IAccessManagerFacet.sol";
import { LibMappings } from "rubic/Libraries/LibMappings.sol";
import { GenericCrossChainFacetV2 as GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacetV2.sol";
import { UnAuthorized } from "src/Errors/GenericErrors.sol";

// Stub GenericCrossChainFacet Contract
contract TestGenericCrossChainFacet is GenericCrossChainFacet, TestFacet {
    constructor() {}
}

contract GenericCrossChainFacetTest is TestBaseFacet {
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
                .startBridgeTokensViaGenericCrossChainV2
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
                .swapAndStartBridgeTokensViaGenericCrossChainV2
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
        testToken = new TestToken("Test", "TST", 18);

        testToken.mint(USER_SENDER, 10_000 ether);

        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = genericCrossChainFacet
            .startBridgeTokensViaGenericCrossChainV2
            .selector;
        functionSelectors[1] = genericCrossChainFacet
            .swapAndStartBridgeTokensViaGenericCrossChainV2
            .selector;
        functionSelectors[2] = genericCrossChainFacet.addDex.selector;
        functionSelectors[3] = genericCrossChainFacet
            .setFunctionApprovalBySignature
            .selector;
        functionSelectors[4] = genericCrossChainFacet
            .updateSelectorInfoV2
            .selector;
        functionSelectors[5] = genericCrossChainFacet.getSelectorInfoV2.selector;

        addFacet(diamond, address(genericCrossChainFacet), functionSelectors);

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
            payable(XSWAPPER),
            XSWAPPER,
            0,
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    ADDRESS_USDC,
                    ADDRESS_USDC,
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

        address[] memory _routers = new address[](1);
        bytes4[] memory _selectors = new bytes4[](1);
        LibMappings.ProviderFunctionInfo[]
            memory _infos = new LibMappings.ProviderFunctionInfo[](1);

        //        0x4039c8d0 // 4
        //        0000000000000000000000000000000000000000000000000000000000000000 // 32
        //        000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 // 32
        //        000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 // 32
        //        0000000000000000000000000000000000000000000000000000000abc123456 // 32
        //        00000000000000000000000000000000000000000000000000000000000000e4 // <-
        //        00000000000000000000000000000000000000000000000000000000000000e4
        //        0000000000000000000000000000000000000000000000000000000000000160
        //        0000000000000000000000000000000000000000000000000000000000000038
        //        000000000000000000000000e9e7cea3dedca5984780bafc599bd69add087d56
        //        00000000000000000000000000000000000000000000000000000000000003e8
        //        0000000000000000000000000000000000000000000000000000000000000064
        //        0000000000000000000000000000000000000000000000000000000000000000

        _routers[0] = XSWAPPER;
        _selectors[0] = IXSwapper.swap.selector;
        _infos[0] = LibMappings.ProviderFunctionInfo(true, 32 * 4 + 4);

        genericCrossChainFacet.updateSelectorInfoV2(
            _routers,
            _selectors,
            _infos
        );
    }

    function testGetSelectorInfo() public {
        LibMappings.ProviderFunctionInfo memory info = genericCrossChainFacet
            .getSelectorInfoV2(XSWAPPER, IXSwapper.swap.selector);

        assertEq(info.offset, 32 * 4 + 4);
    }

    function testCanUpdateSelecotrsWithAccess() public {
        address[] memory _routers = new address[](1);
        bytes4[] memory _selectors = new bytes4[](1);
        LibMappings.ProviderFunctionInfo[]
            memory _infos = new LibMappings.ProviderFunctionInfo[](1);

        _routers[0] = XSWAPPER;
        _selectors[0] = IXSwapper.swap.selector;
        _infos[0] = LibMappings.ProviderFunctionInfo(true, 32 * 4 + 4);

        IAccessManagerFacet(address(genericCrossChainFacet)).setCanExecute(
            GenericCrossChainFacet.updateSelectorInfoV2.selector,
            address(123),
            true
        );

        vm.prank(address(123));

        genericCrossChainFacet.updateSelectorInfoV2(
            _routers,
            _selectors,
            _infos
        );
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

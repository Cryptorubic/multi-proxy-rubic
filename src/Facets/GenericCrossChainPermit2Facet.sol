// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibMappings } from "../Libraries/LibMappings.sol";
import { IRubic } from "../Interfaces/IRubic.sol";
import { IPermit2 } from "../Interfaces/IPermit2.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized, LengthMissmatch, InvalidContract, ZeroAddress } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Generic Cross-Chain Facet Permit2
/// @notice An additional Facet for standard GenericCrossChainFacet
///         Provides functionality for bridging through arbitrary cross-chain provider
///         Utilizes Permit2 functionality for approvals
contract GenericCrossChainPermit2Facet is
    IRubic,
    ReentrancyGuard,
    SwapperV2,
    Validatable
{
    IPermit2 private immutable PERMIT;

    constructor(address _permit) {
        if (_permit == address(0)) {
            revert ZeroAddress();
        }

        PERMIT = IPermit2(_permit);
    }

    /// Events ///

    event SelectorToInfoUpdated(
        address[] _routers,
        bytes4[] _selectors,
        LibMappings.ProviderFunctionInfo[] _infos
    );

    /// Types ///

    /// @param router Address of the router that has to be called
    /// @param approveTo Address of the gateway to approve to
    /// @param extraNative Amount of native to send to a router
    /// @param callData Calldata that has to be passed to the router
    struct GenericCrossChainData {
        address router;
        address approveTo;
        uint256 extraNative;
        bytes callData;
    }

    /// Modifiers ///

    modifier validateGenericData(GenericCrossChainData calldata _genericData) {
        if (!LibAsset.isContract(_genericData.router))
            revert InvalidContract();
        _;
    }

    /// External Methods ///

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function startBridgeTokensViaGenericCrossChainPermit2(
        IRubic.BridgeData memory _bridgeData,
        GenericCrossChainData calldata _genericData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            _genericData.extraNative,
            _bridgeData.integrator
        );

        _startBridge(
            _bridgeData,
            _patchGenericCrossChainData(_genericData, _bridgeData.minAmount)
        );
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider with swaps before bridging
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function swapAndStartBridgeTokensViaGenericCrossChainPermit2(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        GenericCrossChainData calldata _genericData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(_bridgeData.refundee),
            _genericData.extraNative
        );

        _startBridge(
            _bridgeData,
            _patchGenericCrossChainData(_genericData, _bridgeData.minAmount)
        );
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        GenericCrossChainData memory _genericData
    ) internal {
        bool isNative = LibAsset.isNativeAsset(_bridgeData.sendingAssetId);
        uint256 nativeAssetAmount;

        if (isNative) {
            nativeAssetAmount = _bridgeData.minAmount;
        } else {
            LibAsset.maxApproveERC20(
                IERC20(_bridgeData.sendingAssetId),
                address(PERMIT),
                _bridgeData.minAmount
            );

            PERMIT.approve(
                _bridgeData.sendingAssetId,
                _genericData.approveTo,
                uint160(_bridgeData.minAmount),
                uint48(block.timestamp)
            );
        }

        (bool success, bytes memory res) = _genericData.router.call{
            value: nativeAssetAmount + _genericData.extraNative
        }(_genericData.callData);
        if (!success) {
            string memory reason = LibUtil.getRevertMsg(res);
            revert(reason);
        }

        emit RubicTransferStarted(_bridgeData);
    }

    function _patchGenericCrossChainData(
        GenericCrossChainData calldata _genericData,
        uint256 amount
    ) private view returns (GenericCrossChainData memory) {
        LibMappings.GenericCrossChainMappings storage sm = LibMappings
            .getGenericCrossChainMappings();
        LibMappings.ProviderFunctionInfo memory info = sm.selectorToInfo[
            _genericData.router
        ][bytes4(_genericData.callData[:4])];

        if (info.isAvailable) {
            if (info.offset > 0) {
                return
                    GenericCrossChainData(
                        _genericData.router,
                        _genericData.approveTo,
                        _genericData.extraNative,
                        bytes.concat(
                            _genericData.callData[:info.offset],
                            abi.encode(amount),
                            _genericData.callData[info.offset + 32:]
                        )
                    );
            } else {
                return
                    GenericCrossChainData(
                        _genericData.router,
                        _genericData.approveTo,
                        _genericData.extraNative,
                        _genericData.callData
                    );
            }
        } else {
            revert UnAuthorized();
        }
    }
}

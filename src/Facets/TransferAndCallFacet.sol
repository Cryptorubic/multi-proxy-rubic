// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { ITransferAndCall } from "../Interfaces/ITransferAndCall.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized, LengthMissmatch, InvalidContract } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Transfer Facet
/// @notice Provides functionality for bridging via transferAndCall external call
contract TransferAndCallFacet is
    IRubic,
    ReentrancyGuard,
    SwapperV2,
    Validatable
{
    /// Types ///

    /// @param receiver Address where to send tokens and which to call
    /// @param data Data to call the receiver with
    struct TransferAndCallData {
        address receiver;
        bytes data;
    }

    /// External Methods ///

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _transferAndCallData data specific to TransferAndCallFacet
    function startBridgeTokensViaTransferAndCall(
        IRubic.BridgeData memory _bridgeData,
        TransferAndCallData calldata _transferAndCallData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        validateBridgeData(_bridgeData)
        noNativeAsset(_bridgeData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _transferAndCallData);
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider with swaps before bridging
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _transferAndCallData data specific to TransferAndCallFacet
    function swapAndStartBridgeTokensViaTransferAndCall(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        TransferAndCallData calldata _transferAndCallData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        noNativeAsset(_bridgeData)
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(_bridgeData.refundee)
        );

        _startBridge(_bridgeData, _transferAndCallData);
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via transferAndCall external call
    /// @param _bridgeData the core information needed for bridging
    /// @param _transferAndCallData data specific to TransferAndCallFacet
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        TransferAndCallData memory _transferAndCallData
    ) internal {
        ITransferAndCall(_bridgeData.sendingAssetId).transferAndCall(
            _transferAndCallData.receiver,
            _bridgeData.minAmount,
            _transferAndCallData.data
        );

        emit RubicTransferStarted(_bridgeData);
    }
}

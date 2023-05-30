// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized, LengthMissmatch, InvalidContract } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Transfer Facet
/// @notice Provides functionality for bridging through basic ERC-20 transfer or native send
contract TransferFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    /// Types ///

    /// @param destination Address where to send tokens
    struct TransferData {
        address payable destination;
    }

    /// External Methods ///

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _transferData data specific to TransferFacet
    function startBridgeTokensViaTransfer(
        IRubic.BridgeData memory _bridgeData,
        TransferData calldata _transferData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        validateBridgeData(_bridgeData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _transferData);
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider with swaps before bridging
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _transferData data specific to TransferFacet
    function swapAndStartBridgeTokensViaTransfer(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        TransferData calldata _transferData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
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

        _startBridge(_bridgeData, _transferData);
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via basic ERC-20 transfer
    /// or native send to the specified address
    /// @param _bridgeData the core information needed for bridging
    /// @param _transferData data specific to TransferFacet
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        TransferData memory _transferData
    ) internal {
        if (LibAsset.isNativeAsset(_bridgeData.sendingAssetId)) {
            LibAsset.transferNativeAsset(
                _transferData.destination,
                _bridgeData.minAmount
            );
        } else {
            LibAsset.transferERC20(
                _bridgeData.sendingAssetId,
                _transferData.destination,
                _bridgeData.minAmount
            );
        }

        emit RubicTransferStarted(_bridgeData);
    }
}

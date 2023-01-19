// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { ISymbiosisMetaRouter } from "../Interfaces/ISymbiosisMetaRouter.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { InformationMismatch } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Symbiosis Facet
/// @author LI.FI (https://li.fi)
/// @notice Provides functionality for bridging through Symbiosis Protocol
contract SymbiosisFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    /// Storage ///

    bytes32 internal constant NAMESPACE = keccak256("com.rubic.facets.symbiosis");

    /// @notice The contract address of the Symbiosis router on the source chain
    ISymbiosisMetaRouter private immutable symbiosisMetaRouter;
    address private immutable symbiosisGateway;

    /// Types ///

    struct SymbiosisData {
        bytes firstSwapCalldata;
        bytes secondSwapCalldata;
        address[] approvedTokens;
        address firstDexRouter;
        address secondDexRouter;
        address relayRecipient;
        bytes otherSideCalldata;
    }

    /// Constructor ///

    /// @notice Initialize the contract.
    /// @param _symbiosisMetaRouter The contract address of the Symbiosis MetaRouter on the source chain.
    /// @param _symbiosisGateway The contract address of the Symbiosis Gateway on the source chain.
    constructor(ISymbiosisMetaRouter _symbiosisMetaRouter, address _symbiosisGateway) {
        symbiosisMetaRouter = _symbiosisMetaRouter;
        symbiosisGateway = _symbiosisGateway;
    }

    /// External Methods ///

    /// @notice Bridges tokens via Symbiosis
    /// @param _bridgeData the core information needed for bridging
    /// @param _symbiosisData data specific to Symbiosis
    function startBridgeTokensViaSymbiosis(IRubic.BridgeData memory _bridgeData, SymbiosisData calldata _symbiosisData)
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        validateBridgeData(_bridgeData)
        doesNotContainSourceSwaps(_bridgeData)
    {
        validateDestinationCallFlag(_bridgeData, _symbiosisData);

        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _symbiosisData);
    }

    /// @notice Performs a swap before bridging via Symbiosis
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _symbiosisData data specific to Symbiosis
    function swapAndStartBridgeTokensViaSymbiosis(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        SymbiosisData calldata _symbiosisData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
    {
        validateDestinationCallFlag(_bridgeData, _symbiosisData);

        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(msg.sender)
        );

        _startBridge(_bridgeData, _symbiosisData);
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via Symbiosis
    /// @param _bridgeData the core information needed for bridging
    /// @param _symbiosisData data specific to Symbiosis
    function _startBridge(IRubic.BridgeData memory _bridgeData, SymbiosisData calldata _symbiosisData) internal {
        bool isNative = LibAsset.isNativeAsset(_bridgeData.sendingAssetId);
        uint256 nativeAssetAmount;

        if (isNative) {
            nativeAssetAmount = _bridgeData.minAmount;
        } else {
            LibAsset.maxApproveERC20(IERC20(_bridgeData.sendingAssetId), symbiosisGateway, _bridgeData.minAmount);
        }

        symbiosisMetaRouter.metaRoute{ value: nativeAssetAmount }(
            ISymbiosisMetaRouter.MetaRouteTransaction(
                _symbiosisData.firstSwapCalldata,
                _symbiosisData.secondSwapCalldata,
                _symbiosisData.approvedTokens,
                _symbiosisData.firstDexRouter,
                _symbiosisData.secondDexRouter,
                _bridgeData.minAmount,
                isNative,
                _symbiosisData.relayRecipient,
                _symbiosisData.otherSideCalldata
            )
        );

        emit RubicTransferStarted(_bridgeData);
    }

    function validateDestinationCallFlag(IRubic.BridgeData memory _bridgeData, SymbiosisData calldata _symbiosisData)
        private
        pure
    {
        if ((_symbiosisData.otherSideCalldata.length > 0) != _bridgeData.hasDestinationCall) {
            revert InformationMismatch();
        }

        if (_symbiosisData.approvedTokens[0] != _bridgeData.sendingAssetId) {
            revert InformationMismatch();
        }
    }
}

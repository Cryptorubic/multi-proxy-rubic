// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { LibMappings } from "../Libraries/LibMappings.sol";
import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Generic Cross-Chain Facet
/// @author LI.FI (https://li.fi)
/// @notice Provides functionality for bridging through arbitrary cross-chain provider
contract GenericCrossChainFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    using Address for address payable;

    /// Types ///

    struct GenericCrossChainData {
        address payable router;
        bytes callData;
    }

    /// Modifiers ///

    modifier validateGenericData(GenericCrossChainData calldata _genericData) { // TODO:test
        if (_genericData.router == address(LibAsset.getERC20proxy())) {
            revert UnAuthorized();
        }
        _;
    }

    /// External Methods ///

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function startBridgeTokensViaGenericCrossChain(IRubic.BridgeData memory _bridgeData, GenericCrossChainData calldata _genericData)
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _patchGenericCrossChainData(_genericData, _bridgeData.minAmount));
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider with swaps before bridging
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function swapAndStartBridgeTokensViaSymbiosis(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        GenericCrossChainData calldata _genericData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(msg.sender)
        );

        _startBridge(_bridgeData, _patchGenericCrossChainData(_genericData, _bridgeData.minAmount));
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function _startBridge(IRubic.BridgeData memory _bridgeData, GenericCrossChainData memory _genericData) internal {
        bool isNative = LibAsset.isNativeAsset(_bridgeData.sendingAssetId);
        uint256 nativeAssetAmount;

        if (isNative) {
            nativeAssetAmount = _bridgeData.minAmount;
        } else {
            LibAsset.maxApproveERC20(IERC20(_bridgeData.sendingAssetId), _genericData.router, _bridgeData.minAmount);
        }

        _genericData.router.functionCallWithValue(
            _genericData.callData,
            nativeAssetAmount,
            "generic cross-chain call failed"
        );

        emit RubicTransferStarted(_bridgeData);
    }

    function _patchGenericCrossChainData(GenericCrossChainData calldata _genericData, uint256 amount) private view returns(GenericCrossChainData memory) {
        LibMappings.GenericCrossChainMappings storage sm = LibMappings.getGenericCrossChainMappings();
        uint256 offset = sm.providerFunctionAmountOffset[_genericData.router][bytes4(_genericData.callData[:4])];

        return GenericCrossChainData(
            _genericData.router,
            bytes.concat(_genericData.callData[:offset], abi.encode(amount), _genericData.callData[offset+32:])
        );
    }
}

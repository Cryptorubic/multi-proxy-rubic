// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized, NoTransferToNullAddress, LengthMissmatch, InvalidContract, InsufficientBalance, NativeAssetTransferFailed } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

error NoExtraData();
error ERC20TransferFailed();

/// @title Transfer With Bytes Facet
/// @notice Provides functionality for bridging through basic ERC-20 transfer or native send
/// Also provides an ability to attach any bytes to a .transfer() calldata
contract TransferWithBytesFacet is
    IRubic,
    ReentrancyGuard,
    SwapperV2,
    Validatable
{
    /// Types ///

    bytes32 internal constant TRANSFER_WITH_BYTES_NAMESPACE =
        keccak256("com.rubic.transfer.with.bytes");

    struct TransferWithBytesMappings {
        mapping(address => bool) whitelistedReceivers;
    }

    /// @param destination Address where to send tokens
    struct TransferData {
        address payable destination;
        bytes extraData;
    }

    /// EVENTS ///

    event TransferWithBytesWhitelistUpdated(
        address[] addresses,
        bool[] whitelisted
    );

    /// External Methods ///

    /// @notice Adds an address to or removes from the whitelist
    /// @param _addresses Array of addresses
    /// @param _whitelisted Array of corresponding whitelist status to set
    function updateTransferWithBytesWhitelist(
        address[] calldata _addresses,
        bool[] calldata _whitelisted
    ) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }

        if (_addresses.length != _whitelisted.length) {
            revert LengthMissmatch();
        }

        TransferWithBytesMappings storage ms = getTransferWithBytesMappings();

        for (uint64 i; i < _addresses.length; ) {
            ms.whitelistedReceivers[_addresses[i]] = _whitelisted[i];

            unchecked {
                ++i;
            }
        }

        emit TransferWithBytesWhitelistUpdated(_addresses, _whitelisted);
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _transferData data specific to TransferWithBytesFacet
    function startBridgeTokensViaTransferWithBytes(
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
        // Without extra data should use TransferFacet
        if (_transferData.extraData.length == 0) revert NoExtraData();

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
    /// @param _transferData data specific to TransferWithBytesFacet
    function swapAndStartBridgeTokensViaTransferWithBytes(
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
        // Without extra data should use TransferFacet
        if (_transferData.extraData.length == 0) revert NoExtraData();

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
    /// @param _transferData data specific to TransferWithBytesFacet
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        TransferData memory _transferData
    ) internal {
        if (LibAsset.isNativeAsset(_bridgeData.sendingAssetId)) {
            TransferWithBytesMappings
                storage ms = getTransferWithBytesMappings();

            if (!ms.whitelistedReceivers[_transferData.destination])
                revert UnAuthorized();

            transferNativeAssetWithBytes(
                _transferData.destination,
                _bridgeData.minAmount,
                _transferData.extraData
            );
        } else {
            transferERC20WithBytes(
                _bridgeData.sendingAssetId,
                _transferData.destination,
                _bridgeData.minAmount,
                _transferData.extraData
            );
        }

        emit RubicTransferStarted(_bridgeData);
    }

    /// @notice Transfers ether from the inheriting contract to a given
    ///         recipient
    /// Attaches extra bytes to a call as well
    /// @param recipient Address to send ether to
    /// @param amount Amount to send to given recipient
    /// @param extraData Appends to a call
    function transferNativeAssetWithBytes(
        address payable recipient,
        uint256 amount,
        bytes memory extraData
    ) internal {
        if (recipient == LibAsset.NULL_ADDRESS)
            revert NoTransferToNullAddress();
        if (amount > address(this).balance)
            revert InsufficientBalance(amount, address(this).balance);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = recipient.call{ value: amount }(extraData);
        if (!success) revert NativeAssetTransferFailed();
    }

    /// @notice Transfers tokens from the inheriting contract to a given
    ///         recipient
    /// Attaches extra bytes to a .transfer calldata as well
    /// @param assetId Token address to transfer
    /// @param recipient Address to send token to
    /// @param amount Amount to send to given recipient
    /// @param extraData Appends to a call
    function transferERC20WithBytes(
        address assetId,
        address recipient,
        uint256 amount,
        bytes memory extraData
    ) internal {
        // Encode the standard ERC20 transfer function call
        bytes memory transferCall = abi.encodeWithSelector(
            IERC20.transfer.selector,
            recipient,
            amount
        );

        // Concatenate the transfer call with the extra data
        bytes memory callData = abi.encodePacked(transferCall, extraData);

        // Make the low-level call to the token contract
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = assetId.call(callData);

        // Check if the call was successful
        if (!success) revert ERC20TransferFailed();

        // For ERC20 tokens, we need to check the return value
        // Some tokens return nothing, others return a boolean
        if (returnData.length > 0) {
            if (!abi.decode(returnData, (bool))) revert ERC20TransferFailed();
        }
    }

    /// @dev Fetch local storage for TransferWithBytes Facet
    function getTransferWithBytesMappings()
        internal
        pure
        returns (TransferWithBytesMappings storage ms)
    {
        bytes32 position = TRANSFER_WITH_BYTES_NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ms.slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "@axelar-network/axelar-cgp-solidity/contracts/interfaces/IERC20.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { IDexManagerFacet } from "../Interfaces/IDexManagerFacet.sol";
import { LibSwap } from "../Libraries/LibSwap.sol";
import { LibAsset } from "../Libraries/LibAsset.sol";
import { LibBytes } from "../Libraries/LibBytes.sol";
import { IRubic } from "../Interfaces/IRubic.sol";
import { TransferrableOwnership } from "../Helpers/TransferrableOwnership.sol";
import { ZeroAddress, ContractCallNotAllowed } from "../Errors/GenericErrors.sol";

/// @title Executor
/// @notice Arbitrary execution contract used for cross-chain swaps and message passing
contract Executor is IRubic, ReentrancyGuard, TransferrableOwnership {
    /// Storage ///

    /// @dev used to fetch a whitelist
    IDexManagerFacet public diamond;

    /// Errors ///
    error ExecutionFailed();
    error InvalidCaller();

    /// Modifiers ///

    /// @dev Sends any leftover balances back to the user
    modifier noLeftovers(
        LibSwap.SwapData[] calldata _swaps,
        address payable _leftoverReceiver
    ) {
        uint256 numSwaps = _swaps.length;
        if (numSwaps != 1) {
            uint256[] memory initialBalances = _fetchBalances(_swaps);
            address finalAsset = _swaps[numSwaps - 1].receivingAssetId;
            uint256 curBalance = 0;

            _;

            for (uint256 i = 0; i < numSwaps - 1; ) {
                address curAsset = _swaps[i].receivingAssetId;
                // Handle multi-to-one swaps
                if (curAsset != finalAsset) {
                    curBalance = LibAsset.getOwnBalance(curAsset);
                    if (curBalance > initialBalances[i]) {
                        LibAsset.transferAsset(
                            curAsset,
                            _leftoverReceiver,
                            curBalance - initialBalances[i]
                        );
                    }
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            _;
        }
    }

    /// Constructor
    /// @notice Initialize local variables for the Executor
    /// @param _owner The address of owner
    constructor(
        address _owner,
        address _diamond
    ) TransferrableOwnership(_owner) {
        if (_diamond == address(0)) revert ZeroAddress();

        owner = _owner;
        diamond = IDexManagerFacet(_diamond);
    }

    /// @notice Performs a swap before completing a cross-chain transaction
    /// @param _transactionId the transaction id for the swap
    /// @param _swapData array of data needed for swaps
    /// @param _transferredAssetId token received from the other chain
    /// @param _receiver address that will receive tokens in the end
    function swapAndCompleteBridgeTokens(
        bytes32 _transactionId,
        LibSwap.SwapData[] calldata _swapData,
        address _transferredAssetId,
        address payable _receiver
    ) external payable nonReentrant {
        _processSwaps(
            _transactionId,
            _swapData,
            _transferredAssetId,
            _receiver,
            0
        );
    }

    /// Private Methods ///

    /// @notice Performs a series of swaps or arbitrary executions
    /// @param _transactionId the transaction id for the swap
    /// @param _swapData array of data needed for swaps
    /// @param _transferredAssetId token received from the other chain
    /// @param _receiver address that will receive tokens in the end
    /// @param _amount amount of token for swaps or arbitrary executions
    function _processSwaps(
        bytes32 _transactionId,
        LibSwap.SwapData[] calldata _swapData,
        address _transferredAssetId,
        address payable _receiver,
        uint256 _amount
    ) private {
        uint256 startingBalance;
        uint256 finalAssetStartingBalance;
        address finalAssetId = _swapData[_swapData.length - 1]
            .receivingAssetId;
        if (!LibAsset.isNativeAsset(finalAssetId)) {
            finalAssetStartingBalance = LibAsset.getOwnBalance(finalAssetId);
        } else {
            finalAssetStartingBalance =
                LibAsset.getOwnBalance(finalAssetId) -
                msg.value;
        }

        if (!LibAsset.isNativeAsset(_transferredAssetId)) {
            startingBalance = LibAsset.getOwnBalance(_transferredAssetId);
            uint256 allowance = IERC20(_transferredAssetId).allowance(
                msg.sender,
                address(this)
            );
            LibAsset.transferFromERC20(
                _transferredAssetId,
                msg.sender,
                address(this),
                allowance
            );
        } else {
            startingBalance =
                LibAsset.getOwnBalance(_transferredAssetId) -
                msg.value;
        }

        _executeSwaps(_transactionId, _swapData, _receiver);

        uint256 postSwapBalance = LibAsset.getOwnBalance(_transferredAssetId);
        if (postSwapBalance > startingBalance) {
            LibAsset.transferAsset(
                _transferredAssetId,
                _receiver,
                postSwapBalance - startingBalance
            );
        }

        uint256 finalAssetPostSwapBalance = LibAsset.getOwnBalance(
            finalAssetId
        );

        if (finalAssetPostSwapBalance > finalAssetStartingBalance) {
            LibAsset.transferAsset(
                finalAssetId,
                _receiver,
                finalAssetPostSwapBalance - finalAssetStartingBalance
            );
        }

        emit RubicTransferCompleted(
            _transactionId,
            _transferredAssetId,
            _receiver,
            finalAssetPostSwapBalance,
            block.timestamp
        );
    }

    /// @dev Executes swaps one after the other
    /// @param _transactionId the transaction id for the swap
    /// @param _swapData Array of data used to execute swaps
    /// @param _leftoverReceiver Address to receive lefover tokens
    function _executeSwaps(
        bytes32 _transactionId,
        LibSwap.SwapData[] calldata _swapData,
        address payable _leftoverReceiver
    ) private noLeftovers(_swapData, _leftoverReceiver) {
        uint256 numSwaps = _swapData.length;
        for (uint256 i = 0; i < numSwaps; ) {
            LibSwap.SwapData calldata currentSwapData = _swapData[i];

            if (
                !((LibAsset.isNativeAsset(currentSwapData.sendingAssetId) ||
                    diamond.isContractApproved(currentSwapData.approveTo)) &&
                    diamond.isContractApproved(currentSwapData.callTo) &&
                    diamond.isFunctionApproved(
                        LibBytes.getFirst4Bytes(currentSwapData.callData)
                    ))
            ) revert ContractCallNotAllowed();

            LibSwap.swap(_transactionId, currentSwapData);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Fetches balances of tokens to be swapped before swapping.
    /// @param _swapData Array of data used to execute swaps
    /// @return uint256[] Array of token balances.
    function _fetchBalances(
        LibSwap.SwapData[] calldata _swapData
    ) private view returns (uint256[] memory) {
        uint256 numSwaps = _swapData.length;
        uint256[] memory balances = new uint256[](numSwaps);
        address asset;
        for (uint256 i = 0; i < numSwaps; ) {
            asset = _swapData[i].receivingAssetId;
            balances[i] = LibAsset.getOwnBalance(asset);

            if (LibAsset.isNativeAsset(asset)) {
                balances[i] -= msg.value;
            }

            unchecked {
                ++i;
            }
        }

        return balances;
    }

    /// @dev required for receiving native assets from destination swaps
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { Validatable } from "../Helpers/Validatable.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { IAllBridgeCore } from "../Interfaces/IAllBridgeCore.sol";
import { AlreadyInitialized, NotInitialized } from "../Errors/GenericErrors.sol";

contract StellarFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    bytes32 internal constant ALL_BRIDGE_NAMESPACE =
        keccak256("com.rubic.facets.stellar"); // TODO: LibMappings => "com.rubic.library.mappings.stellar"
    uint256 internal constant DEST_CHAIN_ID = 7;
    uint256 internal constant DENOMINATOR = 10 ** 18;

    IAllBridgeCore private immutable allBridgeCore;
    uint256 private immutable allBridgeChainId;

    /// Storage ///

    struct Storage {
        mapping(uint256 => bool) nonceSent;
        bool initialized;
        address relayerFeeReceiver;
        uint256 scalingFactor;
    }

    /// Types ///

    /// @param tokensOut output token address after bridge & final output tokens address after swap (format: hex in destination chain)
    /// @param amountOutMin output token minimum amount in destination chain
    /// @param finalReceiver final receiver address (hex in destination chain)
    /// @param allBridgeReceiver receiver address in allBridge call (hex in destination chain)
    /// @param nonce operation nonce (to prevent message double spending)
    /// @param destinationSwapDeadline for executing the swap on the destination chain
    /// @param allBridgeFee fee for AllBridge protocol in stablecoin
    struct StellarData {
        bytes32[2] tokensOut; // do not use _bridgeData.receivingAssetId cause it has `address` type (not suitable for Stellar addresses & AllBridge protocol)
        uint256 amountOutMin;
        bytes32 finalReceiver; // do not use _bridgeData.receiver cause it has `address` type (not suitable for Stellar addresses & AllBridge protocol)
        bytes32 allBridgeReceiver; // do not use _bridgeData.receiver cause it has `address` type (not suitable for Stellar addresses & AllBridge protocol)
        uint256 nonce;
        uint256 destinationSwapDeadline;
        uint256 allBridgeFee;
    }

    /// Events ///
    /** @notice Params for `Deposit` event
     * @param rubicId txn id in Rubic Ecosystem
     * @param sender address
     * @param integrator address
     * @param tokenIn input token address
     * @param amountIn input token amount
     * @param tokenIntermediateSrc token address after swap (if no source swap, tokenIntermediate should be equal to tokenIn)
     * @param amountIntermediate `tokenIntermediate` amount after source swap
     * @param tokenIntermediateDest output token address after bridge (hex in destination chain)
     * @param tokenOut final output token address after swap (hex in destination chain)
     * @param amountOutMin output token minimum amount
     * @param finalReceiver final receiver address (hex in destination chain)
     * @param allBridgeReceiver receiver address in allBridge call (hex in destination chain)
     * @param allBridgeFee bridge fee amount in USDC (for allBridge)
     * @param destinationChainId destination chain id (in allBridge protocol)
     * @param nonce txn nonce
     * @param deadline for executing the swap on the destination chain
     */
    struct DepositEventParams {
        bytes32 rubicId;
        address sender;
        address integrator;
        address tokenIn;
        uint256 amountIn;
        address tokenIntermediateSrc;
        uint256 amountIntermediate;
        bytes32 tokenIntermediateDest;
        bytes32 tokenOut;
        uint256 amountOutMin;
        bytes32 finalReceiver;
        bytes32 allBridgeReceiver;
        uint256 allBridgeFee;
        uint256 destinationChainId;
        uint256 nonce;
        uint256 deadline;
    }
    /** @notice Event emitted in `deposit`
     * @param params see below in `DepositEventParams` structure
     */
    event Deposit(DepositEventParams params);

    constructor(address _allBridgeCore) {
        allBridgeCore = IAllBridgeCore(_allBridgeCore);
        allBridgeChainId = IAllBridgeCore(_allBridgeCore).chainId();
    }

    /// Init ///

    /// @notice Initialize local variables for the Stellar Facet
    /// @param _feeReceiver Relayer fee receiver address
    /// @param _scalingFactor Multiplier to calculate relayer fee based on the AllBridge protocol fee
    function initialize(
        address _feeReceiver,
        uint256 _scalingFactor
    ) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();

        if (s.initialized) revert AlreadyInitialized();

        s.initialized = true;
        s.relayerFeeReceiver = _feeReceiver;
        s.scalingFactor = _scalingFactor;
    }

    /// External Methods ///

    /// @notice Bridges tokens via AllBridge
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _stellarData Data specific to bridge assets to the Stellar network
    function startBridgeTokensViaAllBridge(
        IRubic.BridgeData memory _bridgeData,
        StellarData calldata _stellarData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        doesNotContainSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        noNativeAsset(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _stellarData);
    }

    /// @notice Performs a swap before bridging via AllBridge
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _swapData An array of swap related data for performing swaps before bridging
    /// @param _stellarData Data specific to bridge assets to the Stellar network
    function swapAndStartBridgeTokensViaAllBridge(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StellarData calldata _stellarData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        noNativeAsset(_bridgeData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(_bridgeData.refundee),
            0
        );

        _startBridge(_bridgeData, _stellarData);
    }

    function setScalingFactor(uint256 _scalingFactor) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();
        if (!s.initialized) revert NotInitialized();
        s.scalingFactor = _scalingFactor;
    }

    function setRelayerFeeReceiver(address _feeReceiver) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();
        if (!s.initialized) revert NotInitialized();
        s.relayerFeeReceiver = _feeReceiver;
    }

    function getNonces(uint256 nonce) external view returns (bool) {
        return getStorage().nonceSent[nonce];
    }

    function getRelayerFeeReceiver() external view returns (address) {
        return getStorage().relayerFeeReceiver;
    }

    function getScalingFactor() external view returns (uint256) {
        return getStorage().scalingFactor;
    }

    /// @dev fetch local storage
    function getStorage() private pure returns (Storage storage s) {
        bytes32 namespace = ALL_BRIDGE_NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := namespace
        }
    }

    /// @notice Calculate relayer fee amount based on the AllBridge fee
    /// @param token address to bridge
    function calculateRelayerFee(address token) public view returns (uint256) {
        return
            (allBridgeCore.getBridgingCostInTokens(
                DEST_CHAIN_ID,
                IAllBridgeCore.MessengerProtocol.Allbridge,
                token
            ) * getStorage().scalingFactor) / DENOMINATOR;
    }

    /// Private Methods ///

    /// @dev Contains the business logic for the bridge via AllBridge into Stellar network
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _stargateData Data specific to bridge assets to the Stellar network
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        StellarData calldata _stellarData
    ) private noNativeAsset(_bridgeData) {
        if (_bridgeData.destinationChainId != DEST_CHAIN_ID) revert();

        Storage storage s = getStorage();

        if (s.nonceSent[_stellarData.nonce]) revert();
        s.nonceSent[_stellarData.nonce] = true;

        uint256 relayerFee = calculateRelayerFee(_bridgeData.sendingAssetId);
        if (relayerFee + _stellarData.allBridgeFee >= _bridgeData.minAmount)
            revert();

        if (relayerFee > 0) {
            _bridgeData.minAmount -= relayerFee;
            LibAsset.transferERC20(
                _bridgeData.sendingAssetId,
                s.relayerFeeReceiver,
                relayerFee
            );
        }

        LibAsset.maxApproveERC20(
            IERC20(_bridgeData.sendingAssetId),
            address(allBridgeCore),
            _bridgeData.minAmount
        );

        allBridgeCore.swapAndBridge(
            _addressToBytes32(_bridgeData.sendingAssetId),
            _bridgeData.minAmount,
            _stellarData.allBridgeReceiver,
            _bridgeData.destinationChainId,
            _stellarData.tokensOut[0],
            _stellarData.nonce,
            IAllBridgeCore.MessengerProtocol.Allbridge,
            _stellarData.allBridgeFee
        );

        emit Deposit(
            DepositEventParams(
                _bridgeData.transactionId,
                msg.sender,
                _bridgeData.integrator,
                _bridgeData.sendingAssetId,
                _bridgeData.minAmount,
                _bridgeData.sendingAssetId,
                _bridgeData.minAmount,
                _stellarData.tokensOut[0],
                _stellarData.tokensOut[1],
                _stellarData.amountOutMin,
                _stellarData.finalReceiver,
                _stellarData.allBridgeReceiver,
                _stellarData.allBridgeFee,
                _bridgeData.destinationChainId,
                _stellarData.nonce,
                _stellarData.destinationSwapDeadline
            )
        );
    }

    function _addressToBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { IStargateRouter } from "../Interfaces/IStargateRouter.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { InvalidAmount, InformationMismatch, InvalidCaller, TokenAddressIsZero, AlreadyInitialized, NotInitialized } from "../Errors/GenericErrors.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { LibMappings } from "../Libraries/LibMappings.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Stargate Facet
/// @notice Provides functionality for bridging through Stargate
contract StargateFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    /// @notice The contract address of the stargate router on the source chain.
    IStargateRouter private immutable router;
    /// @notice The contract address of the native stargate router on the source chain.
    IStargateRouter private immutable nativeRouter;
    /// @notice The contract address of the stargate composer on the source chain.
    IStargateRouter private immutable composer;

    bytes32 internal constant NAMESPACE =
        keccak256("com.rubic.facets.stargate-v2");

    /// Types ///

    struct Storage {
        mapping(uint256 => uint16) layerZeroChainId;
        bool initialized;
    }

    struct ChainIdConfig {
        uint256 chainId;
        uint16 layerZeroChainId;
    }

    /// @param srcPoolId Source pool id.
    /// @param dstPoolId Dest pool id.
    /// @param minAmountLD The min qty you would accept on the destination.
    /// @param dstGasForCall Additional gas fee for extral call on the destination.
    /// @param lzFee Estimated message fee.
    /// @param refundAddress Refund adddress. Extra gas (if any) is returned to this address
    /// @param callTo The address to send the tokens to on the destination.
    /// @param callData Additional payload.
    struct StargateData {
        uint256 srcPoolId;
        uint256 dstPoolId;
        uint256 minAmountLD;
        uint256 dstGasForCall;
        uint256 lzFee;
        address payable refundAddress;
        bytes callTo;
        bytes callData;
    }

    /// Errors ///

    error UnknownLayerZeroChain();

    /// Events ///

    event StargateInitialized(ChainIdConfig[] chainIdConfigs);

    event LayerZeroChainIdSet(
        uint256 indexed chainId,
        uint16 layerZeroChainId
    );

    /// Constructor ///

    constructor(
        IStargateRouter _router,
        IStargateRouter _nativeRouter,
        IStargateRouter _composer
    ) {
        router = _router;
        nativeRouter = _nativeRouter;
        composer = _composer;
    }

    /// Init ///

    /// @notice Initialize local variables for the Stargate Facet
    /// @param chainIdConfigs Chain Id configuration data
    function initStargate(ChainIdConfig[] calldata chainIdConfigs) external {
        LibDiamond.enforceIsContractOwner();

        Storage storage sm = getStorage();

        if (sm.initialized) {
            revert AlreadyInitialized();
        }

        for (uint256 i = 0; i < chainIdConfigs.length; i++) {
            sm.layerZeroChainId[chainIdConfigs[i].chainId] = chainIdConfigs[i]
                .layerZeroChainId;
        }

        sm.initialized = true;

        emit StargateInitialized(chainIdConfigs);
    }

    /// External Methods ///

    /// @notice Bridges tokens via Stargate Bridge
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _stargateData Data specific to Stargate Bridge
    function startBridgeTokensViaStargate(
        IRubic.BridgeData memory _bridgeData,
        StargateData calldata _stargateData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        doesNotContainSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
    {
        validateDestinationCallFlag(_bridgeData, _stargateData);
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            _stargateData.lzFee,
            _bridgeData.integrator
        );
        _startBridge(_bridgeData, _stargateData);
    }

    /// @notice Performs a swap before bridging via Stargate Bridge
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _swapData An array of swap related data for performing swaps before bridging
    /// @param _stargateData Data specific to Stargate Bridge
    function swapAndStartBridgeTokensViaStargate(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData calldata _stargateData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(_bridgeData.refundee))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
    {
        validateDestinationCallFlag(_bridgeData, _stargateData);
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(_bridgeData.refundee),
            _stargateData.lzFee
        );

        _startBridge(_bridgeData, _stargateData);
    }

    function quoteLayerZeroFee(
        uint256 _destinationChainId,
        StargateData calldata _stargateData
    ) external view returns (uint256, uint256) {
        // Transfers with callData have to be routed via the composer which adds additional overhead in fees.
        // The composer exposes the same function as the router to calculate those fees.
        IStargateRouter stargate = _stargateData.callData.length > 0
            ? composer
            : router;
        return
            stargate.quoteLayerZeroFee(
                getLayerZeroChainId(_destinationChainId),
                1, // TYPE_SWAP_REMOTE on Bridge
                _stargateData.callTo,
                _stargateData.callData,
                IStargateRouter.lzTxObj(
                    _stargateData.dstGasForCall,
                    0,
                    toBytes(msg.sender)
                )
            );
    }

    /// Private Methods ///

    /// @dev Contains the business logic for the bridge via Stargate Bridge
    /// @param _bridgeData Data used purely for tracking and analytics
    /// @param _stargateData Data specific to Stargate Bridge
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        StargateData calldata _stargateData
    ) private {
        if (LibAsset.isNativeAsset(_bridgeData.sendingAssetId)) {
            // All transfers with destination calls need to be routed via the composer contract
            IStargateRouter stargate = _bridgeData.hasDestinationCall
                ? composer
                : nativeRouter;

            stargate.swapETHAndCall{
                value: _bridgeData.minAmount + _stargateData.lzFee
            }(
                getLayerZeroChainId(_bridgeData.destinationChainId),
                _stargateData.refundAddress,
                _stargateData.callTo,
                IStargateRouter.SwapAmount(
                    _bridgeData.minAmount,
                    _stargateData.minAmountLD
                ),
                IStargateRouter.lzTxObj(
                    _stargateData.dstGasForCall,
                    0,
                    toBytes(_bridgeData.receiver)
                ),
                _stargateData.callData
            );
        } else {
            // All transfers with destination calls need to be routed via the composer contract
            IStargateRouter stargate = _bridgeData.hasDestinationCall
                ? composer
                : router;

            LibAsset.maxApproveERC20(
                IERC20(_bridgeData.sendingAssetId),
                address(stargate),
                _bridgeData.minAmount
            );

            stargate.swap{ value: _stargateData.lzFee }(
                getLayerZeroChainId(_bridgeData.destinationChainId),
                _stargateData.srcPoolId,
                _stargateData.dstPoolId,
                _stargateData.refundAddress,
                _bridgeData.minAmount,
                _stargateData.minAmountLD,
                IStargateRouter.lzTxObj(
                    _stargateData.dstGasForCall,
                    0,
                    toBytes(_bridgeData.receiver)
                ),
                _stargateData.callTo,
                _stargateData.callData
            );
        }

        emit RubicTransferStarted(_bridgeData);
    }

    function validateDestinationCallFlag(
        IRubic.BridgeData memory _bridgeData,
        StargateData calldata _stargateData
    ) private pure {
        if (
            (_stargateData.callData.length > 0) !=
            _bridgeData.hasDestinationCall
        ) {
            revert InformationMismatch();
        }
    }

    /// Mappings management ///

    /// @notice Sets the Layer 0 chain ID for a given chain ID
    /// @param _chainId uint16 of the chain ID
    /// @param _layerZeroChainId uint16 of the Layer 0 chain ID
    /// @dev This is used to map a chain ID to its Layer 0 chain ID
    function setLayerZeroChainId(
        uint256 _chainId,
        uint16 _layerZeroChainId
    ) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage sm = getStorage();

        if (!sm.initialized) {
            revert NotInitialized();
        }

        sm.layerZeroChainId[_chainId] = _layerZeroChainId;
        emit LayerZeroChainIdSet(_chainId, _layerZeroChainId);
    }

    /// @notice Gets the Layer 0 chain ID for a given chain ID
    /// @param _chainId uint256 of the chain ID
    /// @return uint16 of the Layer 0 chain ID
    function getLayerZeroChainId(
        uint256 _chainId
    ) private view returns (uint16) {
        Storage storage sm = getStorage();
        uint16 chainId = sm.layerZeroChainId[_chainId];
        if (chainId == 0) revert UnknownLayerZeroChain();
        return chainId;
    }

    function toBytes(address _address) private pure returns (bytes memory) {
        return abi.encodePacked(_address);
    }

    /// @dev fetch local storage
    function getStorage() private pure returns (Storage storage s) {
        bytes32 namespace = NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := namespace
        }
    }
}

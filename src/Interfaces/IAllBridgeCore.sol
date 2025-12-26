// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAllBridgeCore {
    enum MessengerProtocol {
        None,
        Allbridge,
        Wormhole,
        LayerZero
    }

    function chainId() external view returns (uint256);

    function swapAndBridge(
        bytes32 token,
        uint amount,
        bytes32 recipient,
        uint destinationChainId,
        bytes32 receiveToken,
        uint nonce,
        MessengerProtocol messenger,
        uint feeTokenAmount
    ) external payable;

    function getBridgingCostInTokens(
        uint destinationChainId,
        MessengerProtocol messenger,
        address tokenAddress
    ) external view returns (uint);
}

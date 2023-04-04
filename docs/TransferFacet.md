# Transfer Facet

## How it works

The Transfer Facet works by transferring provided token to the specified address. Firstly the tokens are transferred on the Diamond Proxy and then after fees subtraction they are transferred to the address.

```mermaid
graph LR;
    D{RubicMultiProGenericCrossChain}-- DELEGATECALL -->A[TransferFacet]
    A -- "IERC20.transfer()" --> id1[ERC20 token]
```

## Public Methods

- `function startBridgeTokensViaTransfer(IRubic.BridgeData memory _bridgeData, TransferData calldata _transferData)`
  - Simply bridges tokens using transfer method
- `function swapAndStartBridgeTokensViaTransfer(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        TransferData calldata _transferData
    )`
  - Performs swap(s) before bridging tokens using transfer method

## TransferFacert Specific Parameters

The specific to GenericCrossChain Facet and is represented as the following struct type:

```solidity
/// @param destination Address where to send tokens
struct TransferData {
    address payable destination;
}

```
## Fees

There are **three** fees included in the transfer proccess:
1) [fixed native fee](./LibFees.md)
2) [token fee](./LibFees.md)

- **Fixed native fee** is subtracted from message value whether there is swap or not.
- **Token fee** is subtracted from the token transferred from user whether there is swap or not.

## Swap Data

Some methods accept a `SwapData _swapData` parameter.

Swapping is performed by a swap specific library that expects an array of calldata to can be run on variaous DEXs (i.e. Uniswap) to make one or multiple swaps before performing another action.

The swap library can be found [here](../src/Libraries/LibSwap.sol).

## Rubic Data

Some methods accept a `BridgeData _bridgeData` parameter.

This parameter is strictly for analytics purposes. It's used to emit events that we can later track and index in our subgraphs and provide data on how our contracts are being used. `BridgeData` and the events we can emit can be found [here](../src/Interfaces/IRubic.sol).

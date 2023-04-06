[![Forge](https://github.com/Cryptorubic/multi-proxy-rubic/actions/workflows/forge.yml/badge.svg)](https://github.com/Cryptorubic/multi-proxy-rubic/actions/workflows/forge.yml)

# Rubic Smart Contracts

## Table of contents

1. [How It Works](#how-it-works)
2. [Architecture](#architecture)
   1. [Contract Flow](#contract-flow)
   2. [Diamond Helper Contracts](#diamond-helper-contracts)
3. [Repository Structure](#repository-structure)
4. [Getting Started](#getting-started)
   1. [INSTALL](#install)
   2. [TEST](#test)
   3. [TEST With Foundry/Forge](#foundry-forge)
5. [Contract Docs](#contract-docs)
6. [Configuration](#configuration)
   1. [Before deployment](#configuration_before)
   2. [After deployment](#configuration_after)
7. [Deploy](#deploy)


## Architecture<a name="architecture"></a>

The Rubic Contract is built using the EIP-2535 (Multi-facet Proxy) standard. The contract logic lives behind a single contract that in turn uses DELEGATECALL to call **facet** contracts that contain the business logic.

All business logic is built using **facet** contracts which live in `src/Facets`.

Since all tokens have to be approved to our contracts. And because it is not safe to approve them to Upgradeable contracts.
Rubic has another contract being a single non-upgradeable entrypoint. This contract transfers tokens from user to the main contract and nothing more.
So all the user's tokens are approved to it and this is safe.

For more information on EIP-2535 you can view the entire EIP [here](https://eips.ethereum.org/EIPS/eip-2535).

---

### Contract Flow<a name="contract-flow"></a>

A basic example would be a user bridging from one chain to another using Symbiosis.
The user would interact with the ERC20Proxy contract which will transfer assets (native or ERC20) from user to the RubicMultiProxy.
Then the main contract will delegate to the SymbiosisFacet and call this way a Symbiosis MetaRouter with specified parameters.

The basic flow is illustrated below.

```mermaid
graph TD;
    ERC20Proxy--> D{RubicMultiProxy};
    D{RubicMultiProxy}-- DELEGATECALL -->GenericCrossChainFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->GenericSwapFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->MultichainFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->StargateFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->SymbiosisFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->XYFacet;
```

---

### Diamond Helper Contracts<a name="diamond-helper-contracts"></a>

The RubicMultiProxy contract is deployed along with some helper contracts that facilitate things like upgrading facet contracts, look-ups for methods on facet contracts, ownership checking and withdrawals of funds. For specific details please check out [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).

```mermaid
graph TD;
    D{RubicMultiProxy}-- DELEGATECALL -->DiamondCutFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->DiamondLoupeFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->OwnershipFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->WithdrawFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->FeesFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->AccessManagerFacet;
    D{RubicMultiProxy}-- DELEGATECALL -->DexManagerFacet;
```

## Repository Structure<a name="repository-structure"></a>

```
contracts
│ README.md                   // you are here
│ ...                         // setup and development configuration files
│
├─── config                   // service configuration files
├─── constants                // general constants
├─── deploy                   // deployment scripts
├─── diamondABI               // Diamond ABI definition
├─── export                   // deployed results
├─── scripts                  // scripts containing sample calls for demonstration
│
├─── src                      // the contract code
│   ├── Facets                // service facets
│   ├── Interfaces            // interface definitions
│   └── Libraries             // library definitions
│
├───tasks
│   │ generateDiamondABI.ts   // script to generate Diamond ABI including all facets
│
├─── test                     // contract unit tests
│   ├─── facets               // facet tests
│   ├─── fixtures             // service fixtures for running the tests
│   └─── utils                // testing utility functions
│
└─── utils                    // utility scripts
```

## Contract Docs<a name="contract-docs"></a>

You can read more details documentation on each facet [here](./docs/README.md).
Sample requests to fetch transactions for each facet can be found at the end of each section.

## Getting Started<a name="getting-started"></a>

Make sure to copy `.env.example` to `.env` and fill out the missing values.

### INSTALL<a name="install"></a>

```bash
yarn
```

### TEST<a name="test"></a>

```bash
yarn test
```

### TEST With Foundry/Forge<a name="foundry-forge"></a>

Make sure to install the latest version of Foundry by downloading the installer.

```
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your PATH, run it to get the latest forge and cast binaries:

```
foundryup
```

Install dependencies

```
forge install
```

Run tests

```
forge test
```

OR

```
yarn test:forge
```

## Configuration<a name="configuration"></a>

### Before deployment<a name="configuration_before"></a>

For the complete deployment of the project some configuration must be performed.

1) There are some config files placed in [config](./config) directory:
   1) [dexs.json](./config/dexs.json) - addresses of DEXs that should be whitelisted on corresponding blockchain
   2) [sigs.json](./config/sigs.json) - function's signatures that should be whitelisted on corresponding blockchain
   3) Configs related to a specific cross-chain provider:
      1) [multichain.json](./config/multichain.json) - For each blockchain: **anyNative** - address of AnyToken which underlying is WNative, **routers** - address allowed to be called within MultichainFacet
      2) [multichainTokens.json](config/multichainTokens.json) - For each blockcahin: **chainID**, **mappings** - array of **tokenAddress** address of ANY token and **anyTokenAddress** address of original token
      2) [symbiosis.json](./config/symbiosis.json) - For each blockchain: **metaRouter** - address of Symbiosis metaRouter, **gateway** - address of Symbiosis gateway
      3) [stargate.json](./config/stargate.json) - **routers** - address of the Stargate router for each blockchain;
      For each blockchain: **chainId** - blockchain ID, **lzChainId** - Stargate's original blockchain ID;
      **pools**: For each blockchain: **address** - address of target token, **id** - corresponding Stargate's target pool ID
      4) [xy.json](./config/xy.json) - For each blockchain: **XSwapper** - address of the XSwapper
   4) [offests.json](./config/offsets.json) - For each blockchain: an array of structs (**router** - address of provider's router, **selector** - selector of function being configured, **offset** - position in calldata to patch)
   5) [fees.json](./config/fees.json) - Contains **maxRubicFee** spread for all blockchains; For each blockchain: **feeTreasury** address, **maxFixedNativeFee**
2) RPC urls have to be inserted in `.env` file

### After deployment<a name="configuration_after"></a>

After the deployment some settings can be altered.

1) Fees:
   1) `setMaxRubicPlatformFee` - set max token fee in percents
   2) `setRubicPlatformFee` - set current token fee in percents
   3) `setFixedNativeFee` - set current fixed native fee
   4) `setIntegratorInfo` - set updates fee info related to specific integrator: tokenFee, Rubic share of token fee, fixed native fee, Rubic share of fixed native fee
   5) `setFeeTreasure` - set address of fee treasury
2) Dexes:
   1) `addDex`, `batchAddDex` - add DEX's address in whitelist
   2) `removeDex`, `batchRemoveDex` - remove DEX's address from whitelist
   3) `setFunctionApprovalBySignature`, batchSetFunctionApprovalBySignature - add or remove signature from whitelist
3) Diamond:
   1) `diamondCut` - add, remove or alter a Facet

Authorisation for these functions is described in [this table](https://docs.google.com/spreadsheets/d/1PPT1XLdLAZt__ZsQodsXe7ZTunx6AmWGVasflpR-brM/edit#gid=0)

### DEPLOY<a name="deploy"></a>

You can deploy the entire project by running:

`yarn deploy <network> --tags DeployAllFacets`

You can deploy individual facets by running:

`yarn deploy <network> --tags Deploy<facet> // e.g. DeployNXTPFacet`

DEX Manager is a special facet that manages allowed DEXs and allowed function calls. You can update these allowed DEXs/functions by updating `/config/dex.ts` and then running:

`yarn deploy <network> --tags DeployDexManagerFacet`

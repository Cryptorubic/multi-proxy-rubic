import '@nomiclabs/hardhat-ethers'
import fs from 'fs'
import { HardhatUserConfig } from 'hardhat/types'
import '@typechain/hardhat'
import 'hardhat-preprocessor'
import { node_url, accounts } from './utils/network'
import '@nomiclabs/hardhat-etherscan'
import '@matterlabs/hardhat-zksync-deploy'
import '@matterlabs/hardhat-zksync-solc'
import '@matterlabs/hardhat-zksync-verify'
import * as dotenv from 'dotenv'
dotenv.config()

export const DEFAULT_PRIVATE_KEY =
  process.env.MNEMONIC ||
  '1000000000000000000000000000000000000000000000000000000000000000'
export const FILE_SUFFIX = process.env.PRODUCTION ? '' : 'staging.'

require('./tasks/generateDiamondABI.ts')

function getRemappings() {
  return fs
    .readFileSync('remappings.txt', 'utf8')
    .split('\n')
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split('='))
}

const config: HardhatUserConfig = {
  zksolc: {
    version: '1.3.10',
    compilerSource: 'binary',
    settings: {},
  },
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 1337,
      initialBaseFeePerGas: 0, // to fix : https://github.com/sc-forks/solidity-coverage/issues/652, see https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136
      // process.env.HARDHAT_FORK will specify the network that the fork is made from.
      // this line ensure the use of the corresponding accounts
      accounts: accounts(process.env.HARDHAT_FORK),
      forking: process.env.HARDHAT_FORK
        ? {
            // TODO once PR merged : network: process.env.HARDHAT_FORK,
            url: node_url(process.env.HARDHAT_FORK),
            blockNumber: process.env.HARDHAT_FORK_NUMBER
              ? parseInt(process.env.HARDHAT_FORK_NUMBER)
              : undefined,
          }
        : undefined,
      zksync: false,
    },
    goerli: {
      url: 'https://eth-goerli.public.blastapi.io',
      zksync: false,
    },
    zkSyncTestnet: {
      url: `${process.env.ETH_NODE_URI_ZKSYNC_TESTNET}`,
      ethNetwork: 'goerli', // or a Goerli RPC endpoint from Infura/Alchemy/Chainstack etc.
      zksync: true,
      verifyURL:
        'https://zksync2-testnet-explorer.zksync.dev/contract_verification',
      accounts: [`0x${DEFAULT_PRIVATE_KEY}`],
    },
    ethereum: {
      url: `${process.env.ETH_NODE_URI_MAINNET}`,
      chainId: 1,
      zksync: false,
      accounts: [`0x${DEFAULT_PRIVATE_KEY}`],
    },
    zkSync: {
      url: `${process.env.ETH_NODE_URI_ZKSYNC}`,
      ethNetwork: 'ethereum', // or a Goerli RPC endpoint from Infura/Alchemy/Chainstack etc.
      zksync: true,
      verifyURL:
        'https://zksync2-mainnet-explorer.zksync.io/contract_verification',
      accounts: [`0x${DEFAULT_PRIVATE_KEY}`],
    },
  },
  defaultNetwork: 'ethereum',
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to)
              break
            }
          }
        }
        return line
      },
    }),
  },
  paths: {
    sources: './src',
    cache: './cache_hardhat',
  },
}

export default config

import fetch from 'node-fetch'
import blockchainsData from '../config/multichainTokens.json'
import fs from 'fs'
import chalk from 'chalk'

const msg = (msg: string) => {
  console.log(chalk.green(msg))
}

interface AnyMapping {
  tokenAddress: string
  anyTokenAddress: string
}

interface Blockchain {
  chainID: number
  mappings: AnyMapping[]
}

const blockchains = <Record<string, Blockchain>>(<unknown>blockchainsData)

async function main(): Promise<void> {
  for (const blockchainName in blockchains) {
    msg('Fetching for ' + blockchainName)
    const response = await fetch(
      'https://bridgeapi.anyswap.exchange/v4/tokenlistv4/' +
        blockchains[blockchainName].chainID,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json',
        },
      }
    )

    const jsonData = <any>await response.json()

    const fetchedTokens: AnyMapping[] = []

    for (const key in jsonData) {
      let found = false
      const destChains = jsonData[key].destChains as any[]
      for (const chainKey in destChains) {
        if (found) break
        const chainPaths = destChains[chainKey] as any[]
        for (const chainPathKey in chainPaths) {
          if (
            chainPaths[chainPathKey].routerABI ===
            'anySwapOutUnderlying(fromanytoken,toAddress,amount,toChainID)'
          ) {
            fetchedTokens.push({
              tokenAddress: chainPaths[chainPathKey].fromanytoken.address,
              anyTokenAddress: jsonData[key].address,
            })
            found = true
            break
          }
        }
      }
    }

    blockchains[blockchainName].mappings = fetchedTokens

    console.log(fetchedTokens.length)
    fs.writeFileSync(
      'config/multichainTokens.json',
      JSON.stringify(blockchains, null, 2)
    )
    msg('Written for ' + blockchainName)
  }
}

main()

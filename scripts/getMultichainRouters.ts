import fetch from 'node-fetch'
import blockchainsData from '../config/multichain.json'
import fs from 'fs'
import chalk from 'chalk'

const msg = (msg: string) => {
  console.log(chalk.green(msg))
}

interface Blockchain {
  chainID: number
  anyNative: string
  routers: string[]
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

    const fetchedTokenRouters: string[] = []

    for (const key in jsonData) {
      let found = false
      const destChains = jsonData[key].destChains as any[]
      for (const chainKey in destChains) {
        if (found) break
        const chainPaths = destChains[chainKey] as any[]
        for (const chainPathKey in chainPaths) {
          if (
            chainPaths[chainPathKey].routerABI === 'Swapout(amount,toAddress)'
          ) {
            fetchedTokenRouters.indexOf(chainPaths[chainPathKey].router) === -1
              ? fetchedTokenRouters.push(chainPaths[chainPathKey].router)
              : (found = true)
            break
          }
        }
      }
    }

    const fetchedAnyRouters: string[] = []

    for (const key in jsonData) {
      let found = false
      const destChains = jsonData[key].destChains as any[]
      for (const chainKey in destChains) {
        if (found) break
        const chainPaths = destChains[chainKey] as any[]
        for (const chainPathKey in chainPaths) {
          if (
            chainPaths[chainPathKey].routerABI ===
              'anySwapOut(fromanytoken,toAddress,amount,toChainID)' ||
            chainPaths[chainPathKey].routerABI ===
              'anySwapOutUnderlying(fromanytoken,toAddress,amount,toChainID)' ||
            chainPaths[chainPathKey].routerABI ===
              'anySwapOutNative(fromanytoken,toAddress,toChainID,{value: amount})'
          ) {
            fetchedAnyRouters.indexOf(chainPaths[chainPathKey].router) === -1
              ? fetchedAnyRouters.push(chainPaths[chainPathKey].router)
              : (found = true)
            break
          }
        }
      }
    }

    blockchains[blockchainName].routers =
      fetchedTokenRouters.concat(fetchedAnyRouters)

    console.log(blockchains[blockchainName].routers.length)
    fs.writeFileSync(
      'config/multichain.json',
      JSON.stringify(blockchains, null, 2)
    )
    msg('Written for ' + blockchainName)
  }
}

main()

import { Wallet } from 'zksync-ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Deployer } from '@matterlabs/hardhat-zksync-deploy'
import { DEFAULT_PRIVATE_KEY } from '../hardhat.config'
import fs from 'fs'

let constructorArgs = []

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script`)

  // Initialize the wallet.
  const wallet = new Wallet(DEFAULT_PRIVATE_KEY)

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, wallet)
  // Load contract
  const artifact = await deployer.loadArtifact('XYFacet')

  const rawdata = fs.readFileSync(`config/xy.json`, 'utf-8')
  const configRaw = JSON.parse(rawdata)

  const config = <Record<string, any>>(<unknown>configRaw.config)

  constructorArgs = [config[hre.network.name].XSwapper]

  // Deploy this contract. The returned object will be of a `Contract` type,
  // similar to the ones in `ethers`.
  const deployedContract = await deployer.deploy(artifact, constructorArgs)

  // Show the contract info.
  console.log(
    JSON.stringify({
      address: deployedContract.address,
      constructorArgs: constructorArgs,
    })
  )
}

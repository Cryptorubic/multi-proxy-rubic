// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { StellarFacet } from "rubic/Facets/StellarFacet.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("StellarFacet") {}

    function run()
        public
        returns (StellarFacet deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            vm.projectRoot(),
            "/config/allbridge.json"
        );
        string memory json = vm.readFile(path);
        address allBridgeCore = json.readAddress(
            string.concat(".addresses.", network)
        );

        constructorArgs = abi.encode(allBridgeCore);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (StellarFacet(payable(predicted)), constructorArgs);
        }

        if (networkSupportsCreate3(network)) {
            deployed = StellarFacet(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(StellarFacet).creationCode,
                            constructorArgs
                        )
                    )
                )
            );
        } else {
            deployed = new StellarFacet(allBridgeCore);
        }

        vm.stopBroadcast();
    }
}

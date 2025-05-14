// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { GenericCrossChainPermit2Facet } from "rubic/Facets/GenericCrossChainPermit2Facet.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("GenericCrossChainPermit2Facet") {}

    function run()
        public
        returns (
            GenericCrossChainPermit2Facet deployed,
            bytes memory constructorArgs
        )
    {
        string memory path = string.concat(
            vm.projectRoot(),
            "/config/permit2.json"
        );
        string memory json = vm.readFile(path);
        address permitAddress = json.readAddress(
            string.concat(".config.", network, ".permit2_address")
        );

        constructorArgs = abi.encode(permitAddress);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (
                GenericCrossChainPermit2Facet(payable(predicted)),
                constructorArgs
            );
        }

        if (networkSupportsCreate3(network)) {
            deployed = GenericCrossChainPermit2Facet(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(GenericCrossChainPermit2Facet).creationCode,
                            constructorArgs
                        )
                    )
                )
            );
        } else {
            deployed = new GenericCrossChainPermit2Facet(permitAddress);
        }

        vm.stopBroadcast();
    }
}

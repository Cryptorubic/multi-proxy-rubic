// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { GenericCrossChainFacetV2 as GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacetV2.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("GenericCrossChainFacetV2") {}

    function run() public returns (GenericCrossChainFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return GenericCrossChainFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = GenericCrossChainFacet(
                factory.deploy(salt, type(GenericCrossChainFacet).creationCode)
            );
        } else {
            deployed = new GenericCrossChainFacet();
        }

        vm.stopBroadcast();
    }
}

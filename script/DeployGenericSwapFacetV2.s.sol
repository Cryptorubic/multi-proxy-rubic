// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { GenericSwapFacetV2 as GenericSwapFacet } from "rubic/Facets/GenericSwapFacetV2.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("GenericSwapFacetV2") {}

    function run() public returns (GenericSwapFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return GenericSwapFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = GenericSwapFacet(
                factory.deploy(salt, type(GenericSwapFacet).creationCode)
            );
        } else {
            deployed = new GenericSwapFacet();
        }

        vm.stopBroadcast();
    }
}

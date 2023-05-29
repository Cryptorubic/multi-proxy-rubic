// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { DexManagerFacet } from "rubic/Facets/DexManagerFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("DexManagerFacet") {}

    function run() public returns (DexManagerFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return DexManagerFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = DexManagerFacet(
                factory.deploy(salt, type(DexManagerFacet).creationCode)
            );
        } else {
            deployed = new DexManagerFacet();
        }

        vm.stopBroadcast();
    }
}

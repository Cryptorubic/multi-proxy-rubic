// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { MultichainFacet } from "rubic/Facets/MultichainFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("MultichainFacet") {}

    function run() public returns (MultichainFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return MultichainFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = MultichainFacet(
                factory.deploy(salt, type(MultichainFacet).creationCode)
            );
        } else {
            deployed = new MultichainFacet();
        }

        vm.stopBroadcast();
    }
}

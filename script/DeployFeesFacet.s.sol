// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { FeesFacet } from "rubic/Facets/FeesFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("FeesFacet") {}

    function run() public returns (FeesFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return FeesFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = FeesFacet(
                factory.deploy(salt, type(FeesFacet).creationCode)
            );
        } else {
            deployed = new FeesFacet();
        }

        vm.stopBroadcast();
    }
}

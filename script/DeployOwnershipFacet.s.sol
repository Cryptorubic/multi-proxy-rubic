// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { OwnershipFacet } from "rubic/Facets/OwnershipFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("OwnershipFacet") {}

    function run() public returns (OwnershipFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return OwnershipFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = OwnershipFacet(
                factory.deploy(salt, type(OwnershipFacet).creationCode)
            );
        } else {
            deployed = new OwnershipFacet();
        }

        vm.stopBroadcast();
    }
}

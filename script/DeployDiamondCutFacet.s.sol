// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { DiamondCutFacet } from "rubic/Facets/DiamondCutFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("DiamondCutFacet") {}

    function run() public returns (DiamondCutFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return DiamondCutFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = DiamondCutFacet(
                factory.deploy(salt, type(DiamondCutFacet).creationCode)
            );
        } else {
            deployed = new DiamondCutFacet();
        }

        vm.stopBroadcast();
    }
}

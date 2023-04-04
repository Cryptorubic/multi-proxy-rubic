// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { TransferFacet } from "rubic/Facets/TransferFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("TransferFacet") {}

    function run() public returns (TransferFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return TransferFacet(predicted);
        }

        deployed = TransferFacet(
            factory.deploy(salt, type(TransferFacet).creationCode)
        );

        vm.stopBroadcast();
    }
}

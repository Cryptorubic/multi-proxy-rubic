// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { TransferAndCallFacet } from "rubic/Facets/TransferAndCallFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("TransferAndCallFacet") {}

    function run() public returns (TransferAndCallFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return TransferAndCallFacet(predicted);
        }

        deployed = TransferAndCallFacet(
            factory.deploy(salt, type(TransferAndCallFacet).creationCode)
        );

        vm.stopBroadcast();
    }
}

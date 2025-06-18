// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { TransferWithBytesFacet } from "rubic/Facets/TransferWithBytesFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("TransferWithBytesFacet") {}

    function run() public returns (TransferWithBytesFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return TransferWithBytesFacet(predicted);
        }

        if (networkSupportsCreate3(network)) {
            deployed = TransferWithBytesFacet(
                factory.deploy(salt, type(TransferWithBytesFacet).creationCode)
            );
        } else {
            deployed = new TransferWithBytesFacet();
        }

        vm.stopBroadcast();
    }
}

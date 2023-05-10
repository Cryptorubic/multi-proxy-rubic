// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { Executor } from "rubic/Periphery/Executor.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("Executor") {}

    function run()
        public
        returns (Executor deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            root,
            "/deployments/",
            network,
            ".",
            fileSuffix,
            "json"
        );
        string memory json = vm.readFile(path);
        address diamond = json.readAddress(".RubicMultiProxy");

        constructorArgs = abi.encode(deployerAddress, diamond);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (Executor(payable(address(predicted))), constructorArgs);
        }

        if (networkSupportsCreate3(network)) {
            deployed = Executor(
                payable(
                    address(
                        factory.deploy(
                            salt,
                            bytes.concat(
                                type(Executor).creationCode,
                                constructorArgs
                            )
                        )
                    )
                )
            );
        } else {
            deployed = new Executor(deployerAddress, diamond);
        }

        vm.stopBroadcast();
    }
}

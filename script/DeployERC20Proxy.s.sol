// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { ERC20Proxy } from "rubic/Periphery/ERC20Proxy.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("ERC20Proxy") {}

    function run()
        public
        returns (ERC20Proxy deployed, bytes memory constructorArgs)
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

        if (keccak256(abi.encodePacked(fileSuffix)) == keccak256("staging.")) {
            vm.startBroadcast(deployerPrivateKey);

            if (isDeployed()) {
                return (ERC20Proxy(payable(predicted)), constructorArgs);
            }

            deployed = ERC20Proxy(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(ERC20Proxy).creationCode,
                            constructorArgs
                        )
                    )
                )
            );

            vm.stopBroadcast();
        } else {
            deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY_ERC20PROXY"));

            vm.startBroadcast(deployerPrivateKey);

            deployed = new ERC20Proxy(deployerAddress, diamond);

            vm.stopBroadcast();
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { StargateFacet, IStargateRouter } from "rubic/Facets/StargateFacet.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("StargateFacet") {}

    function run()
        public
        returns (StargateFacet deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            vm.projectRoot(),
            "/config/stargate.json"
        );
        string memory json = vm.readFile(path);

        address stargateRouter = json.readAddress(
            string.concat(".routers.", network)
        );
        address stargateNativeRouter = json.readAddress(
            string.concat(".nativeRouters.", network)
        );
        address stargateComposer = json.readAddress(
            string.concat(".composers.", network)
        );

        constructorArgs = abi.encode(
            stargateRouter,
            stargateNativeRouter,
            stargateComposer
        );

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (StargateFacet(payable(predicted)), constructorArgs);
        }

        if (networkSupportsCreate3(network)) {
            deployed = StargateFacet(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(StargateFacet).creationCode,
                            constructorArgs
                        )
                    )
                )
            );
        } else {
            deployed = new StargateFacet(
                IStargateRouter(stargateRouter),
                IStargateRouter(stargateNativeRouter),
                IStargateRouter(stargateComposer)
            );
        }

        vm.stopBroadcast();
    }
}

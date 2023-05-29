// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { XYFacet, IXSwapper } from "rubic/Facets/XYFacet.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("XYFacet") {}

    function run()
        public
        returns (XYFacet deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            vm.projectRoot(),
            "/config/xy.json"
        );
        string memory json = vm.readFile(path);
        address xswapper = json.readAddress(
            string.concat(".config.", network, ".XSwapper")
        );

        constructorArgs = abi.encode(xswapper);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (XYFacet(payable(predicted)), constructorArgs);
        }

        if (networkSupportsCreate3(network)) {
            deployed = XYFacet(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(XYFacet).creationCode,
                            constructorArgs
                        )
                    )
                )
            );
        } else {
            deployed = new XYFacet(IXSwapper(xswapper));
        }

        vm.stopBroadcast();
    }
}

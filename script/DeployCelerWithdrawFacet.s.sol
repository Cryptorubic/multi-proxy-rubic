// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { CelerWithdrawFacet, ICelerWithdraw } from "rubic/Facets/CelerWithdrawFacet.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("CelerWithdrawFacet") {}

    function run()
        public
        returns (CelerWithdrawFacet deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            vm.projectRoot(),
            "/config/celer.json"
        );
        string memory json = vm.readFile(path);
        address celer = json.readAddress(
            string.concat(".config.", network, ".cBridgeV2")
        );

        constructorArgs = abi.encode(celer);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (CelerWithdrawFacet(payable(predicted)), constructorArgs);
        }

        if (networkSupportsCreate3(network)) {
            deployed = CelerWithdrawFacet(
                payable(
                    factory.deploy(
                        salt,
                        bytes.concat(
                            type(CelerWithdrawFacet).creationCode,
                            constructorArgs
                        )
                    )
                )
            );
        } else {
            deployed = new CelerWithdrawFacet(ICelerWithdraw(celer));
        }

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UpdateScriptBase } from "../utils/UpdateScriptBase.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { MultichainFacet } from "rubic/Facets/MultichainFacet.sol";

contract DeployScript is UpdateScriptBase {
    using stdJson for string;

    function run() public {
        string memory path = string.concat(
            root,
            "/config/multichainTokens.json"
        );
        string memory json = vm.readFile(path);
        bytes memory anyMappingsRaw = json.parseRaw(
            string.concat(".", network)
        );
        MultichainFacet.AnyMapping[] memory anyMappings = abi.decode(
            anyMappingsRaw,
            (MultichainFacet.AnyMapping[])
        );

        vm.startBroadcast(deployerPrivateKey);

        MultichainFacet(diamond).updateAddressMappings(anyMappings);

        vm.stopBroadcast();
    }
}

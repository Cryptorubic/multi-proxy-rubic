// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UpdateScriptBase } from "./utils/UpdateScriptBase.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { DiamondCutFacet, IDiamondCut } from "rubic/Facets/DiamondCutFacet.sol";
import { DeBridgeFacet } from "rubic/Facets/DeBridgeFacet.sol";

contract DeployScript is UpdateScriptBase {
    using stdJson for string;

    function run() public returns (address[] memory facets) {
        string memory path = string.concat(root, "/deployments/", network, ".", fileSuffix, "json");

        string memory json = vm.readFile(path);
        address facet = json.readAddress(".DeBridgeFacet");

        vm.startBroadcast(deployerPrivateKey);

        // DeBridge
        if (loupe.facetFunctionSelectors(facet).length == 0) {
            bytes4[] memory exclude;
//            exclude[0] = (bytes4(hex'b1c902bf'));
//            exclude[1] = (bytes4(hex'a1518823'));
            cut.push(
                IDiamondCut.FacetCut({
                    facetAddress: address(facet),
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: getSelectors("DeBridgeFacet", exclude)
                })
            );
            cutter.diamondCut(cut, address(0), "");
        }

        facets = loupe.facetAddresses();

        vm.stopBroadcast();
    }
}

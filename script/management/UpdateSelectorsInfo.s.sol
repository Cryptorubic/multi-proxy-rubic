// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UpdateScriptBase } from "../utils/UpdateScriptBase.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacet.sol";
import { LibMappings } from "rubic/Libraries/LibMappings.sol";

contract DeployScript is UpdateScriptBase {
    using stdJson for string;
    address[] memory routers;
    bytes4[] memory selectors;
    LibMappings.ProviderFunctionInfo[]
            memory selectorsInfo;

    struct SelectorInfo {
        uint256 offset;
        address router;
        bytes selector;
    }

    function convertBytesToBytes4(
        bytes memory inBytes
    ) private pure returns (bytes4 outBytes4) {
        assembly {
            outBytes4 := mload(add(inBytes, 32))
        }
    }

    function run() public returns(uint256 number) {
        string memory path = string.concat(root, "/config/offsets.json");
        string memory json = vm.readFile(path);
        bytes memory selectorInfosRaw = json.parseRaw(
            string.concat(".", network)
        );

        SelectorInfo[] memory selectorInfosParsed = abi.decode(
            selectorInfosRaw,
            (SelectorInfo[])
        );

//        address[] memory routers = new address[](selectorInfosParsed.length);
//        bytes4[] memory selectors = new bytes4[](selectorInfosParsed.length);
//        LibMappings.ProviderFunctionInfo[]
//            memory selectorsInfo = new LibMappings.ProviderFunctionInfo[](
//                selectorInfosParsed.length
//            );

        for (uint i; i < selectorInfosParsed.length; i++) {
            bytes4 selector = convertBytesToBytes4(
                selectorInfosParsed[i].selector
            );

            LibMappings.ProviderFunctionInfo memory setInfo = GenericCrossChainFacet(diamond).getSelectorInfo(selectorInfosParsed[i].router, selector);
            if (setInfo.isAvailable == false) {
                number++;

                routers.push(selectorInfosParsed[i].router);
                selectors.push(selector);
                selectorsInfo.push(LibMappings.ProviderFunctionInfo(
                        true,
                        selectorInfosParsed[i].offset
                    )
                );
            }
        }

        vm.startBroadcast(deployerPrivateKey);

        GenericCrossChainFacet(diamond).updateSelectorInfo(
            routers,
            selectors,
            selectorsInfo
        );

        vm.stopBroadcast();

        return number;
    }
}

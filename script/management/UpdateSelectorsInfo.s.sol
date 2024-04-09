// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UpdateScriptBase } from "../utils/UpdateScriptBase.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { GenericCrossChainFacetV2 as GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacetV2.sol";
import { LibMappings } from "rubic/Libraries/LibMappings.sol";

contract DeployScript is UpdateScriptBase {
    using stdJson for string;
    address[] routers;
    bytes4[] selectors;
    LibMappings.ProviderFunctionInfo[] selectorsInfo;

    struct SelectorInfo {
        bool isAvailable;
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

    function run() public returns (uint256 number) {
        string memory path = string.concat(root, "/config/offsets.json");
        string memory json = vm.readFile(path);
        bytes memory selectorInfosRaw = json.parseRaw(
            string.concat(".", network)
        );

        SelectorInfo[] memory selectorInfosParsed = abi.decode(
            selectorInfosRaw,
            (SelectorInfo[])
        );

        for (uint i; i < selectorInfosParsed.length; i++) {
            bytes4 selector = convertBytesToBytes4(
                selectorInfosParsed[i].selector
            );

            LibMappings.ProviderFunctionInfo
                memory setInfo = GenericCrossChainFacet(diamond)
                    .getSelectorInfoV2(selectorInfosParsed[i].router, selector);
            if (
                setInfo.isAvailable != selectorInfosParsed[i].isAvailable ||
                setInfo.offset != selectorInfosParsed[i].offset
            ) {
                number++;

                routers.push(selectorInfosParsed[i].router);
                selectors.push(selector);
                selectorsInfo.push(
                    LibMappings.ProviderFunctionInfo(
                        selectorInfosParsed[i].isAvailable,
                        selectorInfosParsed[i].offset
                    )
                );
            }
        }

        vm.startBroadcast(deployerPrivateKey);

        GenericCrossChainFacet(diamond).updateSelectorInfoV2(
            routers,
            selectors,
            selectorsInfo
        );

        vm.stopBroadcast();

        return number;
    }
}

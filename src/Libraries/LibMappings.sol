// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { CannotAuthoriseSelf, UnAuthorized } from "../Errors/GenericErrors.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";

/// @title Mappings Library
/// @notice Provides mappings for all facets that may need them
library LibMappings {
    /// Types ///
    bytes32 internal constant WORMHOLE_NAMESPACE =
        keccak256("com.rubic.library.mappings.wormhole");
    bytes32 internal constant AMAROK_NAMESPACE =
        keccak256("com.rubic.library.mappings.amarok");
    bytes32 internal constant GENERIC_CROSS_CHAIN_NAMESAPCE =
        keccak256("com.rubic.library.mappings.generic.cross.chain");

    /// Storage ///

    struct WormholeMappings {
        mapping(uint256 => uint16) wormholeChainId;
        bool initialized;
    }

    struct AmarokMappings {
        mapping(uint256 => uint32) amarokDomain;
    }

    struct ProviderFunctionInfo {
        bool isAvailable;
        uint256 offset;
    }

    struct GenericCrossChainMappings {
        mapping(address => mapping(bytes4 => ProviderFunctionInfo)) selectorToInfo;
    }

    /// @dev Fetch local storage for Wormhole
    function getWormholeMappings()
        internal
        pure
        returns (WormholeMappings storage ms)
    {
        bytes32 position = WORMHOLE_NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ms.slot := position
        }
    }

    /// @dev Fetch local storage for Amarok
    function getAmarokMappings()
        internal
        pure
        returns (AmarokMappings storage ms)
    {
        bytes32 position = AMAROK_NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ms.slot := position
        }
    }

    /// @dev Fetch local storage for Generic Cross Chain
    function getGenericCrossChainMappings()
        internal
        pure
        returns (GenericCrossChainMappings storage ms)
    {
        bytes32 position = GENERIC_CROSS_CHAIN_NAMESAPCE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ms.slot := position
        }
    }
}

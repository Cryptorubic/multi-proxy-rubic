// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IDexManagerFacet {
    /// @notice Register the address of a DEX contract to be approved for swapping.
    /// @param _dex The address of the DEX contract to be approved.
    function addDex(address _dex) external;

    /// @notice Batch register the address of DEX contracts to be approved for swapping.
    /// @param _dexs The addresses of the DEX contracts to be approved.
    function batchAddDex(address[] calldata _dexs) external;

    /// @notice Unregister the address of a DEX contract approved for swapping.
    /// @param _dex The address of the DEX contract to be unregistered.
    function removeDex(address _dex) external;

    /// @notice Batch unregister the addresses of DEX contracts approved for swapping.
    /// @param _dexs The addresses of the DEX contracts to be unregistered.
    function batchRemoveDex(address[] calldata _dexs) external;

    /// @notice Adds/removes a specific function signature to/from the allowlist
    /// @param _signature the function signature to allow/disallow
    /// @param _approval whether the function signature should be allowed
    function setFunctionApprovalBySignature(
        bytes4 _signature,
        bool _approval
    ) external;

    /// @notice Batch Adds/removes a specific function signature to/from the allowlist
    /// @param _signatures the function signatures to allow/disallow
    /// @param _approval whether the function signatures should be allowed
    function batchSetFunctionApprovalBySignature(
        bytes4[] calldata _signatures,
        bool _approval
    ) external;

    /// @notice Returns whether a function signature is approved
    /// @param _signature the function signature to query
    /// @return approved Approved or not
    function isFunctionApproved(
        bytes4 _signature
    ) external view returns (bool approved);

    /// @notice Returns a list of all approved DEX addresses.
    /// @return addresses List of approved DEX addresses
    function approvedDexs() external view returns (address[] memory addresses);

    /// @dev Checks whether a contract address has been added to the allow list
    /// @param _contract the contract address to check
    function isContractApproved(
        address _contract
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibAsset } from "../Libraries/LibAsset.sol";

/// @title ERC20 Proxy
/// @notice Proxy contract for safely transferring ERC20 tokens for swaps/executions
contract ERC20Proxy {
    address public diamond;

    /// Constructor
    constructor() {
        diamond = msg.sender;
    }

    /// @notice Transfers tokens from address to the diamond
    /// @param tokenAddress the ERC20 contract address of the token to send
    /// @param from the address to transfer from
    /// @param amount the amount of tokens to send
    function transferFrom(
        address tokenAddress,
        address from,
        uint256 amount
    ) external {
        LibAsset.transferFromERC20(tokenAddress, from, diamond, amount);
    }
}

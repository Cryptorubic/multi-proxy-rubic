// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LibAsset } from "../Libraries/LibAsset.sol";

/// @title ERC20 Proxy
/// @notice Proxy contract for safely transferring ERC20 tokens for swaps/executions
contract ERC20Proxy is Ownable {
    /// Constructor
    constructor() {}

    /// @notice Transfers tokens from one address to another specified address
    /// @param tokenAddress the ERC20 contract address of the token to send
    /// @param from the address to transfer from
    /// @param to the address to transfer to
    /// @param amount the amount of tokens to send
    function transferFrom(
        address tokenAddress,
        address from,
        address to,
        uint256 amount
    ) external onlyOwner {
        LibAsset.transferFromERC20(tokenAddress, from, to, amount);
    }
}

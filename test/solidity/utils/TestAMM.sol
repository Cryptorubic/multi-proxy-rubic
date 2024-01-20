// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { TestToken as ERC20 } from "./TestToken.sol";

contract TestAMM {
    uint256 public nativeFee = 0.1 ether;

    function swap(
        ERC20 _fromToken,
        uint256 _amountIn,
        ERC20 _toToken,
        uint256 _amountOut
    ) public payable {
        if (address(_fromToken) != address(0)) {
            _fromToken.transferFrom(msg.sender, address(this), _amountIn);
            _fromToken.burn(address(this), _amountIn);
        } else {
            payable(address(0xd34d)).transfer(msg.value);
        }

        _toToken.mint(msg.sender, _amountOut);
    }

    function swapWithExtraNative(
        ERC20 _fromToken,
        uint256 _amountIn,
        ERC20 _toToken,
        uint256 _amountOut
    ) public payable {
        if (address(_fromToken) != address(0)) {
            require(msg.value >= nativeFee, "Not enough native fees");

            _fromToken.transferFrom(msg.sender, address(this), _amountIn);
            _fromToken.burn(address(this), _amountIn);
        } else {
            require(
                msg.value - _amountIn >= nativeFee,
                "Not enough native fees"
            );

            payable(address(0xd34d)).transfer(_amountIn);
        }

        _toToken.mint(msg.sender, _amountOut);
    }

    function swapWithLeftover(
        ERC20 _fromToken,
        uint256 _amountIn,
        ERC20 _toToken,
        uint256 _amountOut
    ) public payable {
        if (address(_fromToken) != address(0)) {
            _fromToken.transferFrom(msg.sender, address(this), _amountIn);
            _fromToken.burn(address(this), _amountIn / 2);

            _fromToken.transfer(msg.sender, _amountIn / 2);
        } else {
            payable(address(0xd34d)).transfer(msg.value);
        }

        _toToken.mint(msg.sender, _amountOut);
    }
}

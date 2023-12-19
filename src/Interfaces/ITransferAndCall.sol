// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ITransferAndCall {
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external;
}

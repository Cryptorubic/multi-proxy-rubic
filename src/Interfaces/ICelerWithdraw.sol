// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICelerWithdraw {
    function withdraw(
        bytes calldata _wdmsg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;
}

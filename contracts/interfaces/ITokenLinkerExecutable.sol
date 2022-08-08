// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// General interface for upgradable contracts
interface ITokenLinkerExecutable {
    function processLinkedToken(
        address tokenAddress,
        string calldata sourceChain,
        address sourceAddress,
        uint256 amount,
        bytes calldata data
    ) external;
}

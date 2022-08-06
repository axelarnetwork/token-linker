// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from './IProxied.sol';

interface ITokenLinker is IProxied {
    event Sending(string destinationChain, address destinationAddress, uint256 amount);
    event Receiving(string sourceChain, address destinationAddress, uint256 amount);

    function implementationType() external view returns(uint256);

    function sendToken(
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable;
}
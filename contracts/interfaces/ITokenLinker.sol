// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from './IProxied.sol';
import { ITokenLinkerFactory } from './ITokenLinkerFactory.sol';
import { IFactoryUpgradable } from './IFactoryUpgradable.sol';

interface ITokenLinker is IProxied, IFactoryUpgradable {
    error TokenLinkerZeroAddress();

    event Sending(string destinationChain, address indexed destinationAddress, uint256 indexed amount);
    event SendingWithData(
        string destinationChain,
        address indexed destinationAddress,
        uint256 indexed amount,
        address indexed from,
        bytes data
    );
    event Receiving(string sourceChain, address indexed destinationAddress, uint256 indexed amount);
    event ReceivingWithData(
        string sourceChain,
        address indexed destinationAddress,
        uint256 indexed amount,
        address indexed from,
        bytes data
    );

    function token() external view returns (address);

    function sendToken(
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable;

    function sendTokenWithData(
        string memory destinationChain,
        address to,
        uint256 amount,
        bytes calldata data
    ) external payable;
}

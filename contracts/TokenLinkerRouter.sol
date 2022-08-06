// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { ITokenLinker } from './interfaces/ITokenLinker.sol';
import { ITokenLinkerFactory } from './interfaces/ITokenLinkerFactory.sol';

contract TokenLinkerRouter {
    bytes32[] public tokenLinkerIds;

    ITokenLinkerFactory public immutable factory;

    constructor(bytes32[] memory tokenLinkerIds_) {
        factory = ITokenLinkerFactory(msg.sender);
        tokenLinkerIds = tokenLinkerIds_;
    }

    function tokenLinker(uint256 i) public view returns (address) {
        return factory.tokenLinker(tokenLinkerIds[i]);
    }
}
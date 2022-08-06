// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from './TokenLinker.sol';
import { ERC20 } from '../utils/ERC20.sol';

contract TokenLinkerMintBurn is TokenLinker, ERC20 {
    error MintFailed();
    error BurnFailed();

    uint256 public immutable override implementationType = 1;

    constructor(
        address gatewayAddress_,
        address gasServiceAddress_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) {}

    function _setup(bytes calldata data) internal override {
        (name, symbol, decimals) = abi.decode(data, (string, string, uint8));
    }

    function _giveToken(address to, uint256 amount) internal override {
        _mint(to, amount);
    }

    function _takeToken(address from, uint256 amount) internal override {
        _burn(from, amount);
    }
}

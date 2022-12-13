// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from '../TokenLinker.sol';
import { ITokenLinkerFactory } from '../../interfaces/ITokenLinkerFactory.sol';
import { ERC20 } from '../../utils/ERC20.sol';

contract TokenLinkerMintBurn is TokenLinker, ERC20 {
    error MintFailed();
    error BurnFailed();

    constructor(address gatewayAddress_, address gasServiceAddress_) TokenLinker(gatewayAddress_, gasServiceAddress_) {}

    function token() public view override returns (address) {
        return address(this);
    }
    function implementationType() public pure override returns (ITokenLinkerFactory.TokenLinkerType tlt) {
        tlt = ITokenLinkerFactory.TokenLinkerType.mintBurn;
    }

    function _setup(bytes calldata data) internal override {
        super._setup(data);
        (name, symbol, decimals) = abi.decode(data, (string, string, uint8));
    }

    function _giveToken(address to, uint256 amount) internal override {
        _mint(to, amount);
    }

    function _takeToken(address from, uint256 amount) internal override {
        _burn(from, amount);
    }
}

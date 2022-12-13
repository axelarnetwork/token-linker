// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerVersioned } from '../TokenLinkerVersioned.sol';
import { ITokenLinkerFactory } from '../../../interfaces/ITokenLinkerFactory.sol';

contract TokenLinkerMintBurnExternal is TokenLinkerVersioned {
    error MintFailed();
    error BurnFailed();

    address public tokenAddress;
    bytes4 public mintSelector;
    bytes4 public burnSelector;

    constructor(address gatewayAddress_, address gasServiceAddress_, uint256 version) TokenLinkerVersioned(gatewayAddress_, gasServiceAddress_, version) {}

    function token() public view override returns (address) {
        return tokenAddress;
    }
    function implementationType() public pure override returns (ITokenLinkerFactory.TokenLinkerType tlt) {
        tlt = ITokenLinkerFactory.TokenLinkerType.mintBurnExternal;
    }

    function _setup(bytes calldata data) internal override {
        super._setup(data);
        (tokenAddress, mintSelector, burnSelector) = abi.decode(data, (address, bytes4, bytes4));
    }

    function _giveToken(address to, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(abi.encodeWithSelector(mintSelector, to, amount));
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert MintFailed();
    }

    function _takeToken(address from, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(abi.encodeWithSelector(burnSelector, from, amount));
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert BurnFailed();
    }
}

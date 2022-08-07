// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from '../TokenLinker.sol';
import { IExternalTokenReference } from '../../interfaces/IExternalTokenReference.sol';

abstract contract TokenLinkerMintBurnExternal is IExternalTokenReference, TokenLinker {
    error MintFailed();
    error BurnFailed();

    address public override tokenAddress;
    bytes4 public mintSelector;
    bytes4 public burnSelector;
    uint256 public immutable override implementationType = 2;

    function _setup(bytes calldata data) internal override {
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

        if (!transferred || tokenAddress.code.length == 0) revert('BurnFailed()');
    }
}

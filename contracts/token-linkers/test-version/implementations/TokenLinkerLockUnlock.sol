// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IERC20 } from '../../../interfaces/IERC20.sol';
import { ITokenLinkerFactory } from '../../../interfaces/ITokenLinkerFactory.sol';
import { TokenLinkerVersioned } from '../TokenLinkerVersioned.sol';

contract TokenLinkerLockUnlock is TokenLinkerVersioned {
    error TransferFailed();
    error TransferFromFailed();

    address public tokenAddress;

    constructor(address gatewayAddress_, address gasServiceAddress_, uint256 version) TokenLinkerVersioned(gatewayAddress_, gasServiceAddress_, version) {}

    function token() public view override returns (address) {
        return tokenAddress;
    }
    function implementationType() public pure override returns (ITokenLinkerFactory.TokenLinkerType tlt) {
        tlt = ITokenLinkerFactory.TokenLinkerType.lockUnlock;
    }

    function _setup(bytes calldata data) internal override {
        super._setup(data);
        (tokenAddress) = abi.decode(data, (address));
    }

    function _giveToken(address to, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFailed();
    }

    function _takeToken(address from, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFromFailed();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IERC20 } from '../../interfaces/IERC20.sol';
import { TokenLinker } from '../TokenLinker.sol';

abstract contract TokenLinkerLockUnlock is TokenLinker {
    error TransferFailed();
    error TransferFromFailed();

    address public tokenAddress;
    uint256 public immutable override implementationType = 0;

    function token() public view override returns (address) {
        return tokenAddress;
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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from '../TokenLinker.sol';

abstract contract TokenLinkerNative is TokenLinker {
    error InsufficientBalance();
    error TranferFromNativeFailed();
    error TransferToFailed();

    //keccak256('native_balance')
    uint256 public constant NATIVE_BALANCE_SLOT = 0x2b1b2f0e2e6377507cc7f28638bed85633f644ec5614112adcc88f3c5e87903a;

    uint256 public immutable override implementationType = 3;

    function token() public pure override returns (address) {
        return address(0);
    }

    function getNativeBalance() public view returns (uint256 nativeBalance) {
        assembly {
            nativeBalance := sload(NATIVE_BALANCE_SLOT)
        }
    }

    function _setNativeBalance(uint256 nativeBalance) internal {
        assembly {
            sstore(NATIVE_BALANCE_SLOT, nativeBalance)
        }
    }

    function _giveToken(address to, uint256 amount) internal override {
        uint256 balance = getNativeBalance();
        if (balance < amount) revert InsufficientBalance();
        (bool success, ) = to.call{ value: amount }('');
        if (!success) revert TransferToFailed();
        _setNativeBalance(balance - amount);
    }

    function _takeToken(
        address, /*from*/
        uint256 amount
    ) internal override {
        uint256 balance = getNativeBalance();
        if (balance + amount > address(this).balance) revert TranferFromNativeFailed();
        _setNativeBalance(balance + amount);
    }

    function _lockNative() internal pure override returns (bool) {
        return true;
    }

    function updateBalance() external payable {
        _setNativeBalance(address(this).balance);
    }
}

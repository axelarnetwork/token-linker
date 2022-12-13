// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerVersioned } from '../TokenLinkerVersioned.sol';
import { ITokenLinkerFactory } from '../../../interfaces/ITokenLinkerFactory.sol';

contract TokenLinkerNative is TokenLinkerVersioned {
    error InsufficientBalance();
    error TranferFromNativeFailed();
    error TransferToFailed();

    //keccak256('native_balance')
    uint256 public constant NATIVE_BALANCE_SLOT = 0x2b1b2f0e2e6377507cc7f28638bed85633f644ec5614112adcc88f3c5e87903a;

    constructor(address gatewayAddress_, address gasServiceAddress_, uint256 version) TokenLinkerVersioned(gatewayAddress_, gasServiceAddress_, version) {}

    function token() public pure override returns (address) {
        return address(0);
    }
    function implementationType() public pure override returns (ITokenLinkerFactory.TokenLinkerType tlt) {
        tlt = ITokenLinkerFactory.TokenLinkerType.native;
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

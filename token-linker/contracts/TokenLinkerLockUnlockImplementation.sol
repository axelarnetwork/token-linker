// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerLockUnlock } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerLockUnlock.sol';
import { TokenLinkerSender } from './TokenLinkerSender.sol';

contract TokenLinkerLockUnlockImplementation is TokenLinkerLockUnlock, TokenLinkerSender {
    constructor(
        address gatewayAddress_,
        address gasService_,
        address tokenAddress_
    ) TokenLinkerSender(gasService_) TokenLinkerLockUnlock(gatewayAddress_, tokenAddress_) {}
}

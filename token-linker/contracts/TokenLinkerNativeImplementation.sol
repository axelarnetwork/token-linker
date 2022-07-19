// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerNative } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerNative.sol';
import { TokenLinkerSender } from './TokenLinkerSender.sol';

contract TokenLinkerNativeImplementation is TokenLinkerNative, TokenLinkerSender {
    constructor(address gatewayAddress_, address gasService_) TokenLinkerSender(gasService_) TokenLinkerNative(gatewayAddress_) {}
    function _lockNative() internal pure override returns (bool) {
        return true;
    }
}

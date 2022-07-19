// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerMintBurn } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerMintBurn.sol';
import { TokenLinkerSender } from './TokenLinkerSender.sol';

contract TokenLinkerMintBurnImplementation is TokenLinkerMintBurn, TokenLinkerSender {
    constructor(
        address gatewayAddress_,
        address gasService_,
        address tokenAddress_
    ) TokenLinkerSender(gasService_) TokenLinkerMintBurn(gatewayAddress_, tokenAddress_) {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { SelfLookupProxy } from './proxies/SelfLookupProxy.sol';

contract TokenLinkerFactoryProxy is SelfLookupProxy {
    // bytes32(uint256(keccak256('token-linker-factory')) - 1)
    bytes32 public constant override contractId = 0xa6c51be88107847c935460e49bbd180f046b860284d379b474442c02536eabe8;
}

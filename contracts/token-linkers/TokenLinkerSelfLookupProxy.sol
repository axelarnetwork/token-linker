// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { SelfLookupProxy } from '../proxies/SelfLookupProxy.sol';

contract TokenLinkerSelfLookupProxy is SelfLookupProxy {
    // bytes32(uint256(keccak256('token-linker')) - 1)
    bytes32 public constant override contractId = 0x6ec6af55bf1e5f27006bfa01248d73e8894ba06f23f8002b047607ff2b1944ba;
}

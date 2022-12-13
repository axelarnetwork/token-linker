// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { Proxy } from './proxies/Proxy.sol';

contract TokenLinkerFactoryProxy is Proxy {
    // bytes32(uint256(keccak256('token-linker-factory')) - 1)
    bytes32 public constant override contractId = 0xa6c51be88107847c935460e49bbd180f046b860284d379b474442c02536eabe8;

    function init(
        address implementationAddress,
        address owner,
        bytes calldata params
    ) external {
        if (implementation() != address(0)) revert AlreadyInitialized();

        _setImplementation(implementationAddress);

        _setOwner(owner);
        _init(params);
    }
}

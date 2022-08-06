// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { SelfImplementationLookup } from './SelfImplementationLookup.sol';
import { Proxy } from './Proxy.sol';
 
abstract contract SelfLookupProxy is Proxy, SelfImplementationLookup {
    error AlreadyInitialized();

    function init(
        address implementationAddress,
        bytes calldata params
    ) external {
        if (implementation() != address(0)) revert AlreadyInitialized();

        _setImplementation(implementationAddress);

        _init(params);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { FactoryImplementationLookup } from './FactoryImplementationLookup.sol';
import { Proxy } from './Proxy.sol';
 
abstract contract FactoryLookupProxy is Proxy, FactoryImplementationLookup {
    error AlreadyInitialized();

    function init(
        uint256 tlt,
        bytes calldata params
    ) external {
        if (factory() != address(0)) revert AlreadyInitialized();

        _setFactory(msg.sender);
        _setTokenLinkerType(tlt);

        _init(params);
    }
}

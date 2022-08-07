// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { SelfImplementationLookup } from './SelfImplementationLookup.sol';
import { Proxy } from './Proxy.sol';
import { Ownable } from './Ownable.sol';

abstract contract SelfLookupProxy is Proxy, SelfImplementationLookup {
    error AlreadyInitialized();

    // keccak256('owner')
    bytes32 internal constant _OWNER_SLOT = 0x02016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0;

    function init(
        address implementationAddress,
        address owner,
        bytes calldata params
    ) external {
        if (implementation() != address(0)) revert AlreadyInitialized();

        _setImplementation(implementationAddress);

        assembly {
            sstore(_OWNER_SLOT, owner)
        }

        _init(params);
    }
}

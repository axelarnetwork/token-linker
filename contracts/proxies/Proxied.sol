// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { FactoryImplementationLookup } from './FactoryImplementationLookup.sol';
import { IProxied } from '../interfaces/IProxied.sol';
import { ImplementationLookup } from './ImplementationLookup.sol';

abstract contract Proxied is IProxied, ImplementationLookup {
    uint256[20] private storageGap;

    function setup(bytes calldata data) external override {
        if ( implementation() == address(0) ) revert NotProxy();

        _setup(data);
    }

    // solhint-disable-next-line no-empty-blocks
    function _setup(bytes calldata data) internal virtual {}
}

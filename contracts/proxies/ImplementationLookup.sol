// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IImplementationLookup } from '../interfaces/IImplementationLookup.sol';

abstract contract ImplementationLookup is IImplementationLookup {
    function implementation() public view override virtual returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { IFreezable } from '../interfaces/IFreezable.sol';
import { IImplementationLookup } from '../interfaces/IImplementationLookup.sol';

interface IUpgradable is IProxied, IFreezable, IImplementationLookup {
    error InvalidImplementation();
    error SetupFailed();

    event Upgraded(address newImplementation);

    function upgrade(address newImplementation, bytes calldata params) external;
}

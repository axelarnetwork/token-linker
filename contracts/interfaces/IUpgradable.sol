// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';

interface IUpgradable is IProxied {
    error InvalidImplementation();
    error InvalidCodeHash();
    error SetupFailed();

    event Upgraded(address newImplementation);

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata params
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';

interface IFactoryUpgradable is IProxied {
    error InvalidImplementation();
    error SetupFailed();
    error InvalidUpgrade();

    event Upgraded(address newImplementation);
    function implementationType() external view returns (ITokenLinkerFactory.TokenLinkerType);

    function upgrade(uint256 newVersion, bytes calldata params) external;
}

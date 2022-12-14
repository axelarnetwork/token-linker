// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxy } from './IProxy.sol';
import { IVersionManaged } from './IVersionManaged.sol';
import { ITokenLinkerFactory } from './ITokenLinkerFactory.sol';

interface ITokenLinkerProxy is IProxy, IVersionManaged {
    error WrongInitialize();

    function factory() external view returns (address);
    function tokenLinkerType() external view returns (ITokenLinkerFactory.TokenLinkerType);
    function factoryManaged() external view returns (bool);

    function init(
        address owner,
        bytes calldata params
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IImplementationLookup } from './IImplementationLookup.sol';

// General interface for upgradable contracts
interface IProxied is IImplementationLookup {
    error NotProxy();

    function setup(bytes calldata data) external;

    function contractId() external pure returns (bytes32);
}

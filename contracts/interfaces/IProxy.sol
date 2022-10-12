// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IImplementationLookup } from './IImplementationLookup.sol';

// General interface for upgradable contracts
interface IProxy is IImplementationLookup {
    error SetupFailed();
    error InvalidImplementation();
    error EtherNotAccepted();

    function contractId() external pure returns (bytes32);
}

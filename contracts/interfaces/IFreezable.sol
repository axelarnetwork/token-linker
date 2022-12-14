// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IOwnable } from './IOwnable.sol';

interface IFreezable is IOwnable {
    error Frozen(); 
    
    function isFrozen() external view returns (bool frozen);
}

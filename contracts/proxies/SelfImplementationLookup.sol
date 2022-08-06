// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IImplementationLookup } from '../interfaces/IImplementationLookup.sol'; 

contract SelfImplementationLookup is IImplementationLookup {

    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function implementation() public view override returns (address implementation_) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function _setImplementation(address implementation_) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }
}
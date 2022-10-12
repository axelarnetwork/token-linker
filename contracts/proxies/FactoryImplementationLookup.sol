// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';
import { ImplementationLookup } from './ImplementationLookup.sol';

contract FactoryImplementationLookup is ImplementationLookup {
    // bytes32(uint256(keccak256('token-linker-type')) - 1)
    bytes32 internal constant _TOKEN_LINKER_TYPE_SLOT = 0x2d65b4026af59de31ee4dbeebefaf08be9980572a7bcfa3f9e010be119ffcc00;

    // bytes32(uint256(keccak256('token-linker-factory')) - 1)
    bytes32 internal constant _FACTORY_SLOT = 0xa6c51be88107847c935460e49bbd180f046b860284d379b474442c02536eabe8;

    function factory() public view returns (address factory_) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            factory_ := sload(_FACTORY_SLOT)
        }
    }

    function tokenLinkerType() public view returns (uint256 tlt) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tlt := sload(_TOKEN_LINKER_TYPE_SLOT)
        }
    }

    function implementation() public view override returns (address implementation_) {
        address factoryAddress = factory();
        if (factoryAddress == address(0)) return address(0);
        implementation_ = ITokenLinkerFactory(factoryAddress).factoryManagedImplementations(tokenLinkerType());
    }

    function _setFactory(address factory_) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_FACTORY_SLOT, factory_)
        }
    }

    function _setTokenLinkerType(uint256 tlt_) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_TOKEN_LINKER_TYPE_SLOT, tlt_)
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';

abstract contract Proxied is IProxied {
    uint256[20] private storageGap;
    // uint256(keccak256('is-implementation')) - 1
    uint256 public constant IS_IMPLEMENTATION_SLOT = 0x75eff25bbe7a08b828395afac870b36ba87ff751b6c6438d727f8989e54e0b22;

    constructor() {
        _setIsImplementation(true);
    }

    modifier onlyProxy() {
        if (isImplementation()) revert NotProxy();
        _;
    }

    function isImplementation() public view returns(bool result) {
        assembly {
            result := sload(IS_IMPLEMENTATION_SLOT)
        }
    }
    function _setIsImplementation(bool shouldInit) internal {
        assembly {
            sstore(IS_IMPLEMENTATION_SLOT, shouldInit)
        }
    }

    function setup(bytes calldata data) external override onlyProxy {
        _setup(data);
    }

    // solhint-disable-next-line no-empty-blocks
    function _setup(bytes calldata data) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IFreezable } from '../interfaces/IFreezable.sol';
import { Ownable } from './Ownable.sol';

abstract contract Freezable is IFreezable, Ownable {
    // uint256(keccak256('frozen-slot')) - 1
    uint256 internal constant FROZEN_SLOT = 0x5b90ea191e18228bd77e4a8f4d2efb8d6814bcde3c46d5c6dfc512b378efce7b;

    modifier notFrozen() {
        if(isFrozen()) revert Frozen();
        _;
    }

    function isFrozen() public virtual view override returns (bool frozen) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            frozen := sload(FROZEN_SLOT)
        }
    }

    function _setFrozen(bool frozen) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(FROZEN_SLOT, frozen)
        }
    }

    function setFroze(bool frozen) external onlyOwner {
        _setFrozen(frozen);
    }
}

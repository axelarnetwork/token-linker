// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IOwnable } from '../interfaces/IOwnable.sol';

abstract contract Ownable is IOwnable {
    // keccak256('owner')
    bytes32 internal constant _OWNER_SLOT = 0x02016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0;

    modifier onlyOwner() {
        if (owner() != msg.sender) revert NotOwner();
        _;
    }

    function owner() public view override returns (address owner_) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            owner_ := sload(_OWNER_SLOT)
        }
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) internal {
        emit OwnershipTransferred(newOwner);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_OWNER_SLOT, newOwner)
        }
    }
}

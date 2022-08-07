// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { SelfImplementationLookup } from './SelfImplementationLookup.sol';
import { Proxy } from './Proxy.sol';
import { Ownable } from './Ownable.sol';
import { IUpgradable } from '../interfaces/IUpgradable.sol';

abstract contract Upgradable is IUpgradable, SelfImplementationLookup, Ownable {
    function upgrade(address newImplementation, bytes calldata params) external override onlyOwner {
        if (implementation() == address(0)) revert NotProxy();
        if (IProxied(newImplementation).contractId() != this.contractId()) revert InvalidImplementation();

        if (params.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = newImplementation.delegatecall(abi.encodeWithSelector(this.setup.selector, params));

            if (!success) revert SetupFailed();
        }

        emit Upgraded(newImplementation);
        _setImplementation(newImplementation);
    }
}

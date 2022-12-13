
// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { ImplementationLookup } from './ImplementationLookup.sol';
import { Proxied } from './Proxied.sol';
import { Ownable } from './Ownable.sol';
import { IFactoryUpgradable } from '../interfaces/IFactoryUpgradable.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';

abstract contract FactoryUpgradable is IFactoryUpgradable, Ownable, Proxied, ImplementationLookup {
    function factory() public virtual view returns (ITokenLinkerFactory) {
        return ITokenLinkerFactory(address(0));
    }

    function version() public virtual view returns (uint256);
    function implementationType() public virtual view override returns (ITokenLinkerFactory.TokenLinkerType);

    function upgrade(uint256 newVersion, bytes calldata params) external override onlyOwner onlyProxy {
        // factoryManaged token linkers will always have a version() equal to the maximum version that a factory has available
        // so we will either revert in the below line, or the line after.
        if( newVersion <= version() ) revert InvalidUpgrade();
        address newImplementation = factory().getImplementation(implementationType(), newVersion);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = newImplementation.delegatecall(abi.encodeWithSelector(this.setup.selector, params));

        if (!success) revert SetupFailed();
        

        emit Upgraded(newImplementation);
        _setImplementation(newImplementation);
    }
}


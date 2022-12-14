
// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxied } from '../interfaces/IProxied.sol';
import { ImplementationLookup } from './ImplementationLookup.sol';
import { Proxied } from './Proxied.sol';
import { Ownable } from '../utils/Ownable.sol';
import { IFactoryUpgradable } from '../interfaces/IFactoryUpgradable.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';
import { IFreezable } from '../interfaces/IFreezable.sol';
import { ITokenLinkerProxy } from '../interfaces/ITokenLinkerProxy.sol';
import { VersionManaged } from '../versioning/VersionManaged.sol';
import { Freezable } from '../utils/Freezable.sol';
import { VersionManagement } from '../libraries/VersionManagement.sol';

abstract contract FactoryUpgradable is IFactoryUpgradable, Ownable, Proxied, ImplementationLookup, VersionManaged, Freezable {
    using VersionManagement for bytes32;

    function factory() public view returns (ITokenLinkerFactory) {
        return ITokenLinkerFactory(ITokenLinkerProxy(address(this)).factory());
    }

    function factoryManaged() public view returns (bool) {
        return ITokenLinkerProxy(address(this)).factoryManaged();
    }

    function isFrozen() public view override(IFreezable, Freezable) returns (bool) {
        if(factoryManaged()) {
            return factory().isFrozen();
        }
        return super.isFrozen();
    }

    function implementationVersion() public virtual view returns (uint256);
    function implementationType() public virtual view override returns (ITokenLinkerFactory.TokenLinkerType);

    function upgrade(uint256 newVersion, bytes calldata params) external override onlyOwner onlyProxy {
        bytes32 vm = getVersionManagement();
        if( newVersion <= vm.getVersion() ) revert InvalidUpgrade();
        address impl;

        if( vm.isFactoryManaged()) {
            if(newVersion != factory().latestVersion()) revert InvalidUpgrade();
            impl = factory().getLatestImplementation(implementationType());
        } else {
            impl = factory().getImplementation(implementationType(), newVersion);
            _setImplementation(impl);
        }
        if(params.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = impl.delegatecall(abi.encodeWithSelector(this.setup.selector, params));
            
            if (!success) revert SetupFailed();
        }

        emit Upgraded(impl);

        _setVersion(newVersion);
    }
}


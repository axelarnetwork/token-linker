// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from './TokenLinker.sol';
import { TokenLinkerLockUnlock } from './implementations/TokenLinkerLockUnlock.sol';
import { TokenLinkerMintBurn } from './implementations/TokenLinkerMintBurn.sol';
import { TokenLinkerMintBurnExternal } from './implementations/TokenLinkerMintBurnExternal.sol';
import { TokenLinkerNative } from './implementations/TokenLinkerNative.sol';
import { Upgradable } from '../proxies/Upgradable.sol';
import { Ownable } from '../proxies/Ownable.sol';

contract TokenLinkerLockUnlockUpgradable is TokenLinkerLockUnlock, Upgradable {
    constructor(
        address gatewayAddress_,
        address gasServiceAddress_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}

contract TokenLinkerMintBurnUpgradable is TokenLinkerMintBurn, Upgradable {
    constructor(
        address gatewayAddress_,
        address gasServiceAddress_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}
contract TokenLinkerMintBurnExternalUpgradable is TokenLinkerMintBurnExternal, Upgradable {
   constructor(
        address gatewayAddress_,
        address gasServiceAddress_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}
contract TokenLinkerNativeUpgradable is TokenLinkerNative, Upgradable {
    constructor(
        address gatewayAddress_,
        address gasServiceAddress_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}


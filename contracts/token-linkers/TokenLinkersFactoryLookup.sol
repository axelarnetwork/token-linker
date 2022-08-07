// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from './TokenLinker.sol';
import { TokenLinkerLockUnlock } from './implementations/TokenLinkerLockUnlock.sol';
import { TokenLinkerMintBurn } from './implementations/TokenLinkerMintBurn.sol';
import { TokenLinkerMintBurnExternal } from './implementations/TokenLinkerMintBurnExternal.sol';
import { TokenLinkerNative } from './implementations/TokenLinkerNative.sol';
import { FactoryImplementationLookup } from '../proxies/FactoryImplementationLookup.sol';

contract TokenLinkerLockUnlockFactoryLookup is TokenLinkerLockUnlock, FactoryImplementationLookup {
    constructor(address gatewayAddress_, address gasServiceAddress_) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}

contract TokenLinkerMintBurnFactoryLookup is TokenLinkerMintBurn, FactoryImplementationLookup {
    constructor(address gatewayAddress_, address gasServiceAddress_) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}

contract TokenLinkerMintBurnExternalFactoryLookup is TokenLinkerMintBurnExternal, FactoryImplementationLookup {
    constructor(address gatewayAddress_, address gasServiceAddress_) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}

contract TokenLinkerNativeFactoryLookup is TokenLinkerNative, FactoryImplementationLookup {
    constructor(address gatewayAddress_, address gasServiceAddress_) TokenLinker(gatewayAddress_, gasServiceAddress_) {}
}

const { deployContract } = require('@axelar-network/axelar-utils-solidity/scripts/utils');

const { createNetwork } = require('@axelar-network/axelar-local-dev');

const TokenLinkerFactory = require('../artifacts/contracts/TokenLinkerFactory.sol/TokenLinkerFactory.json');
const LockUnlock = require('../artifacts/contracts/token-linkers/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const MintBurn = require('../artifacts/contracts/token-linkers/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const MintBurnExternal = require('../artifacts/contracts/token-linkers/TokenLinkerMintBurnExternal.sol/TokenLinkerMintBurnExternal.json');
const Native = require('../artifacts/contracts/token-linkers/TokenLinkerNative.sol/TokenLinkerNative.json');
const Proxy = require('../artifacts/contracts/token-linkers/TokenLinkerProxy.sol/TokenLinkerProxy.json');
const { keccak256, toUtf8Bytes } = require('ethers/lib/utils');

(async () => {
    const chain = await createNetwork();
    const [wallet] = chain.userWallets;
    const impl = [];

    for (const contractJson of [LockUnlock, MintBurn, MintBurnExternal, Native]) {
        impl.push(await deployContract(wallet, contractJson, [chain.gateway.address, chain.gasReceiver.address]));
    }

    const bytecode = Proxy.bytecode;
    const codehash = keccak256(bytecode);
    const factory = await deployContract(wallet, TokenLinkerFactory, [
        ...impl.map((i) => i.address),
        codehash,
        chain.gateway.address,
        chain.gasReceiver.address,
    ]);

    await (await factory.deploy(3, keccak256(toUtf8Bytes('asdasd')), '0x')).wait();
})();

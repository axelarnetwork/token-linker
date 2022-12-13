const { deployUpgradable } = require('@axelar-network/axelar-gmp-sdk-solidity');
const { getDefaultProvider } = require('ethers');
const { createAndExport } = require('@axelar-network/axelar-local-dev');
const { deployContract } = require('@axelar-network/axelar-gmp-sdk-solidity/scripts/utils');
const { keccak256, defaultAbiCoder } = require('ethers/lib/utils');

const TokenLinkerFactory = require('../artifacts/contracts/TokenLinkerFactory.sol/TokenLinkerFactory.json');
const TokenLinkerFactoryProxy = require('../artifacts/contracts/TokenLinkerFactoryProxy.sol/TokenLinkerFactoryProxy.json');

const LockUnlock = require('../artifacts/contracts/token-linkers/implementations/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const MintBurn = require('../artifacts/contracts/token-linkers/implementations/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const MintBurnExternal = require('../artifacts/contracts/token-linkers/implementations/TokenLinkerMintBurnExternal.sol/TokenLinkerMintBurnExternal.json');
const Native = require('../artifacts/contracts/token-linkers/implementations/TokenLinkerNative.sol/TokenLinkerNative.json');

const LockUnlockV = require('../artifacts/contracts/token-linkers/test-version/implementations/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const MintBurnV = require('../artifacts/contracts/token-linkers/test-version/implementations/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const MintBurnExternalV = require('../artifacts/contracts/token-linkers/test-version/implementations/TokenLinkerMintBurnExternal.sol/TokenLinkerMintBurnExternal.json');
const NativeV = require('../artifacts/contracts/token-linkers/test-version/implementations/TokenLinkerNative.sol/TokenLinkerNative.json');

const TokenLinkerProxy = require('../artifacts/contracts/proxies/TokenLinkerProxy.sol/TokenLinkerProxy.json');
const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-gmp-sdk-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');

async function setupLocal(toFund) {
    await createAndExport({
        chainOutputPath: './info/local.json',
        accountsToFund: toFund,
        relayInterval: 100,
    });
}

async function deploy(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const implementations = [];
    console.log(`Deploying implementations on ${chain.name}.`);

    for (const contractJson of [LockUnlock, MintBurn, MintBurnExternal, Native]) {
        implementations.push((await deployContract(wallet, contractJson, [chain.gateway, chain.gasReceiver])).address);
    }

    console.log('Done. Deploying Factory');
    const bytecode = TokenLinkerProxy.bytecode;
    const codehash = keccak256(bytecode);

    const factory = await deployUpgradable(
        chain.constAddressDeployer,
        wallet,
        TokenLinkerFactory,
        TokenLinkerFactoryProxy,
        [ codehash, chain.gateway, chain.gasReceiver, 0, implementations ],
        [],
        defaultAbiCoder.encode(['address[][]'], [implementations.map(impl => [impl])]),
        'factory',
    );
    console.log(`Deployed at ${factory.address}.`);
    chain.factory = factory.address;
}

async function deployMultiversion(chain, walletUnconnected, n=2) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const implementations = [];
    console.log(`Deploying implementations on ${chain.name}.`);
    for (const contractJson of [LockUnlockV, MintBurnV, MintBurnExternalV, NativeV]) {
        const impl = []
        for(let i=0;i<n;i++) {
            impl.push((await deployContract(wallet, contractJson, [chain.gateway, chain.gasReceiver, i])).address);
        }
        implementations.push(impl);
    }

    console.log('Done. Deploying Factory');
    const bytecode = TokenLinkerProxy.bytecode;
    const codehash = keccak256(bytecode);
    const factory = await deployUpgradable(
        chain.constAddressDeployer,
        wallet,
        TokenLinkerFactory,
        TokenLinkerFactoryProxy,
        [ codehash, chain.gateway, chain.gasReceiver, 1, implementations.map(impl => impl[n-1]) ],
        [],
        defaultAbiCoder.encode(['address[][]'], [implementations]),
        'factoryMultiversion',
    );
    console.log(`Deployed at ${factory.address}.`);
    chain.factoryMultiversion = factory.address;
}

async function deployToken(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const contract = await deployContract(wallet, ERC20MintableBurnable, ['Subnet Token', 'ST', 18]);
    chain.token = contract.address;

    return contract;
}

module.exports = {
    setupLocal,
    deploy,
    deployToken,
    deployMultiversion,
};

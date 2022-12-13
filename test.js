
const { getDefaultProvider, ContractFactory, Contract } = require('ethers');
const { deployContract } = require('@axelar-network/axelar-gmp-sdk-solidity/scripts/utils');
const { createNetwork } = require('@axelar-network/axelar-local-dev');
const { keccak256, defaultAbiCoder } = require('ethers/lib/utils');

const TokenLinkerFactory = require('./artifacts/contracts/TokenLinkerFactory.sol/TokenLinkerFactory.json');
const TokenLinkerFactoryProxy = require('./artifacts/contracts/TokenLinkerFactoryProxy.sol/TokenLinkerFactoryProxy.json');

const LockUnlock = require('./artifacts/contracts/token-linkers/implementations/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const MintBurn = require('./artifacts/contracts/token-linkers/implementations/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const MintBurnExternal = require('./artifacts/contracts/token-linkers/implementations/TokenLinkerMintBurnExternal.sol/TokenLinkerMintBurnExternal.json');
const Native = require('./artifacts/contracts/token-linkers/implementations/TokenLinkerNative.sol/TokenLinkerNative.json');

const TokenLinkerProxy = require('./artifacts/contracts/proxies/TokenLinkerProxy.sol/TokenLinkerProxy.json');
const ERC20MintableBurnable = require('./artifacts/@axelar-network//axelar-gmp-sdk-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const { deployUpgradable } = require('@axelar-network/axelar-gmp-sdk-solidity');



async function deploy(chain) {
    const provider = chain.provider;
    const wallet = chain.userWallets[0];
    const implementations = [];
    console.log(`Deploying implementations on ${chain.name}.`);

    for (const contractJson of [LockUnlock, MintBurn, MintBurnExternal, Native]) {
        implementations.push([(await deployContract(wallet, contractJson, [chain.gateway.address, chain.gasReceiver.address])).address]);
    }

    console.log('Done. Deploying Factory');
    const bytecode = TokenLinkerProxy.bytecode;
    const codehash = keccak256(bytecode);
    const factory = await deployUpgradable(
        chain.constAddressDeployer.address,
        wallet,
        TokenLinkerFactory,
        TokenLinkerFactoryProxy,
        [ codehash, chain.gateway.address, chain.gasReceiver.address, 0, implementations.map(impl => impl[0]) ],
        [],
        defaultAbiCoder.encode(['address[][]'], [implementations]),
        'factory',
    );
    console.log(`Deployed at ${factory.address}.`);
    chain.factory = factory.address;
    return factory;
}


(async() => {
    const chain = await createNetwork();
    const factory = await deploy(chain);

    const tl = await (await factory.deploy(3, keccak256(defaultAbiCoder.encode(['string'], ['asdasd'])), '0x', false)).wait();

})();
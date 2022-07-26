'use strict';

const chai = require('chai');
const { getDefaultProvider, Contract, Wallet } = require('ethers');
const { expect } = chai;
const { keccak256, defaultAbiCoder } = require('ethers/lib/utils');
const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');
const { setupLocal, deploy, deployToken } = require("../scripts/factory");
require('dotenv').config();

const ERC20MintableBurnable = require('../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const ITokenLinkerFactory = require('../artifacts/contracts/interfaces/ITokenLinkerFactory.sol/ITokenLinkerFactory.json');
const ITokenLinker = require('../artifacts/contracts/interfaces/ITokenLinker.sol/ITokenLinker.json');
const IUpgradable = require('../artifacts/contracts/interfaces/IUpgradable.sol/IUpgradable.json');
const IERC20 = require('../artifacts/contracts/interfaces/IERC20.sol/IERC20.json');
const IImplementationLookup = require('../artifacts/contracts/interfaces/IImplementationLookup.sol/IImplementationLookup.json');
const TokenLinkerExecutableTest = require('../artifacts/contracts/test/TokenLinkerExecutableTest.sol/TokenLinkerExecutableTest.json');
const { deployContract } = require('@axelar-network/axelar-gmp-sdk-solidity/scripts/utils');

let chains;
let wallet;

const tokenLinkerTypes = [
    {
        name: 'Lock/Unlock',
        factoryRef: 'lockUnlock',
        params: (chain) => defaultAbiCoder.encode(['address'], [chain.token]),
        preSend: async (tokenLinkerAddress, amount, wallet) => {
            const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, wallet);
            const tokenAddress = await tokenLinker.token();
            const token = new Contract(tokenAddress, ERC20MintableBurnable.abi, wallet);
            await (await token.mint(wallet.address, amount)).wait();
            await (await token.approve(tokenLinkerAddress, amount)).wait();
        },
        getBalance: async(tokenLinkerAddress, address, provider) => {
            const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, provider);
            const tokenAddress = await tokenLinker.token();
            const token = new Contract(tokenAddress, ERC20MintableBurnable.abi, provider);
            return await token.balanceOf(address);
        },
    },
    {
        name: 'Mint/Burn',
        factoryRef: 'mintBurn',
        params: (chain) => defaultAbiCoder.encode(['string', 'string', 'uint8'], ['Test Token', 'TT', 13]),
        getBalance: async(tokenLinkerAddress, address, provider) => {
            const tokenLinker = new Contract(tokenLinkerAddress, IERC20.abi, provider);
            return await tokenLinker.balanceOf(address);
        },
    },
    {
        name: 'Mint/Burn External',
        factoryRef: 'mintBurnExternal',
        pre: async(chain, wallet) => {
            const prevToken = chain.token;
            await deployToken(chain, wallet);
            chain.ownedToken = chain.token;
            chain.token = prevToken;
        },
        params: async (chain) => {
            const contract = new Contract(chain.ownedToken, ERC20MintableBurnable.abi);
            let tx = await contract.populateTransaction.mint(wallet.address, 0);
            const mintSelector = tx.data.substring(0, 10);
            tx = await contract.populateTransaction.burn(wallet.address, 0);
            const burnSelector = tx.data.substring(0, 10);
            return defaultAbiCoder.encode(['address', 'bytes4', 'bytes4'], [contract.address, mintSelector, burnSelector]);
        },
        preSend: async (tokenLinkerAddress, amount, wallet) => {
            const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, wallet);
            const tokenAddress = await tokenLinker.token();
            const token = new Contract(tokenAddress, IERC20.abi, wallet);
            await (await token.approve(tokenLinkerAddress, amount)).wait();
        },
        getBalance: async(tokenLinkerAddress, address, provider) => {
            const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, provider);
            const tokenAddress = await tokenLinker.token();
            const token = new Contract(tokenAddress, ERC20MintableBurnable.abi, provider);
            return await token.balanceOf(address);
        },
    },
    {
        name: 'Native',
        factoryRef: 'native',
        params: (chain) => '0x',
        value: true,
        getBalance: async(tokenLinkerAddress, address, provider) => {
            return BigInt(await provider.getBalance(address));
        },
    }
];

async function deployTokenLinker(chain, type, factoryManaged, key = type) {
    const provider = getDefaultProvider(chain.rpc);
    const walletConnected = wallet.connect(provider);
    const factory = new Contract(chain.factory, ITokenLinkerFactory.abi, walletConnected);
    const tlt = tokenLinkerTypes[type];
    if(tlt.pre) await tlt.pre(chain, walletConnected);
    const params = await tlt.params(chain);
    const salt = keccak256(defaultAbiCoder.encode(['string'], [key]));
    await (await factory.deploy(
        type,
        salt,
        params,
        factoryManaged,
    )).wait();
    const id = await factory.getTokenLinkerId(wallet.address, salt);
    const address = await factory.tokenLinker(id, factoryManaged);
    return new Contract(address, ITokenLinker.abi, walletConnected);
}

async function sendToken(fromChain, toChain, id, factoryManaged, amount) {
    const provider = getDefaultProvider(fromChain.rpc);
    const walletConnected = wallet.connect(provider);
    const factory = new Contract(fromChain.factory, ITokenLinkerFactory.abi, walletConnected);
    const tokenLinkerAddress = await factory.tokenLinker(id, factoryManaged);
    const type = await factory.tokenLinkerType(id);
    const tlt = tokenLinkerTypes[type];
    if(tlt.preSend) await tlt.preSend(tokenLinkerAddress, amount, walletConnected);
    const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, walletConnected);
    await (await tokenLinker.sendToken(toChain.name, wallet.address, amount, {value: tlt.value ? amount + 3e6 : 3e6})).wait();
}

async function sendTokenWithData(fromChain, toChain, id, factoryManaged, to, amount, data) {
    const provider = getDefaultProvider(fromChain.rpc);
    const walletConnected = wallet.connect(provider);
    const factory = new Contract(fromChain.factory, ITokenLinkerFactory.abi, walletConnected);
    const tokenLinkerAddress = await factory.tokenLinker(id, factoryManaged);
    const type = await factory.tokenLinkerType(id);
    const tlt = tokenLinkerTypes[type];
    if(tlt.preSend) await tlt.preSend(tokenLinkerAddress, amount, walletConnected);
    const tokenLinker = new Contract(tokenLinkerAddress, ITokenLinker.abi, walletConnected);
    await (await tokenLinker.sendTokenWithData(toChain.name, to, amount, data, {value: tlt.value ? amount + 3e6 : 3e6})).wait();
}

describe('Token Linker Factory', () => {
    before(async () => {
        const deployer_key = keccak256(
            defaultAbiCoder.encode(
                ['string'],
                [process.env.PRIVATE_KEY_GENERATOR],
            ),
        );
        wallet = new Wallet(deployer_key)
        const deployerAddress = new Wallet(deployer_key).address;
        const toFund = [deployerAddress];
        await setupLocal(toFund);
        chains = require('../info/local.json');
        for(const chain of chains) {
            await deployToken(chain, wallet)
            await deploy(chain, wallet);
        }
        setJSON(chains, './info/local.json');
    });

    for(const factoryManaged of [true, false]) {
        for(let i=0; i<4; i++) {
            it(`Should deploy a ${factoryManaged ? 'Factory' : 'Self'} Managed ${tokenLinkerTypes[i].name} token linker`, async () => { 
                const chain = chains[i];
                const provider = getDefaultProvider(chain.rpc);
                const walletConnected = wallet.connect(provider);
                const factory = new Contract(chain.factory, ITokenLinkerFactory.abi, walletConnected);   
                const tl = await deployTokenLinker(chain, i, factoryManaged);
                const contract = new Contract(tl.address, IImplementationLookup.abi, walletConnected);
                const impl = await contract.implementation();
                const implFromFactory = await factory[factoryManaged ? 'factoryManagedImplementations' : 'upgradableImplementations'](i);
                expect(impl).to.equal(implFromFactory);
            });
        }
    }
    for(let i=0; i<4; i++) {
        it(`Should deploy and upgrade an Upgradable ${tokenLinkerTypes[i].name} token linker`, async () => { 
            const chain = chains[i];
            const provider = getDefaultProvider(chain.rpc);
            const walletConnected = wallet.connect(provider);
            const factory = new Contract(chain.factory, ITokenLinkerFactory.abi, walletConnected);   
            const tl = await deployTokenLinker(chain, i, false, 'u' + i);
            const contract = new Contract(tl.address, IImplementationLookup.abi, walletConnected);
            const impl = await contract.implementation();
            const implFromFactory = await factory.upgradableImplementations(i);
            expect(impl).to.equal(implFromFactory);


            const j = (i+1)%4;
            const newTlt = tokenLinkerTypes[j];
            if(newTlt.pre) await newTlt.pre(chain, walletConnected);
            const params = await newTlt.params(chain);
            const implAddress = await factory.upgradableImplementations(j);
            const upgradable = new Contract(tl.address, IUpgradable.abi, walletConnected);
            await (await upgradable.upgrade(
                implAddress,
                params
            )).wait();
            expect(Number(await tl.implementationType())).to.equal(j);
        });
    }
    for(const factoryManaged of [true, false]) {
        for(const source of [0, 3]) {
            for(const destination of [1, 2]) {
                const key = 'key' + source + destination;
                const amountIn = 12345;
                const amountOut = 1234;
                it(`Should use a ${factoryManaged ? 'Factory' : 'Self'} Managed ${tokenLinkerTypes[source].name} and ${tokenLinkerTypes[destination].name} to bridge some assets.`, async () => {
                    const sourceChain = chains[source];
                    const destinationChain = chains[destination];
                    const walletSource = wallet.connect(getDefaultProvider(sourceChain.rpc));
                    const walletDestination = wallet.connect(getDefaultProvider(destinationChain.rpc));
                    const sourceTokenLinker = await deployTokenLinker(sourceChain, source, factoryManaged, key);
                    const destinationTokenLinker = await deployTokenLinker(destinationChain, destination, factoryManaged, key);
                    const factory = new Contract(sourceChain.factory, ITokenLinkerFactory.abi, walletSource);  
                    const length = await factory.numberDeployed();
                    const id = await factory.tokenLinkerIds(length - 1);
                    await sendToken(sourceChain, destinationChain, id, factoryManaged, amountIn);

                    let getBalance = tokenLinkerTypes[destination].getBalance;

                    let balance = await getBalance(destinationTokenLinker.address, wallet.address, walletDestination.provider);
                    await new Promise((resolve) => {
                        setTimeout(() => {
                            resolve();
                        }, 400);
                    });
                    
                    balance = await getBalance(destinationTokenLinker.address, wallet.address, walletDestination.provider) - balance;
                    expect(BigInt(balance)).to.equal(BigInt(amountIn));

                    await sendToken(destinationChain, sourceChain, id, factoryManaged, amountOut);
                    
                    getBalance = tokenLinkerTypes[source].getBalance;
                    balance = await getBalance(sourceTokenLinker.address, wallet.address, walletSource.provider);
                    await new Promise((resolve) => {
                        setTimeout(() => {
                            resolve();
                        }, 400);
                    });
                    balance = await getBalance(sourceTokenLinker.address, wallet.address, walletSource.provider) - balance;
                    expect(BigInt(balance)).to.equal(BigInt(amountOut));
                });

                it(`Should use a ${factoryManaged ? 'Factory' : 'Self'} Managed ${tokenLinkerTypes[source].name} and ${tokenLinkerTypes[destination].name} to bridge some assets with data.`, async () => {
                    const sourceChain = chains[source];
                    const destinationChain = chains[destination];
                    const walletSource = wallet.connect(getDefaultProvider(sourceChain.rpc));
                    const walletDestination = wallet.connect(getDefaultProvider(destinationChain.rpc));
                    const sourceTokenLinker = await deployTokenLinker(sourceChain, source, factoryManaged, key+'data');
                    const destinationTokenLinker = await deployTokenLinker(destinationChain, destination, factoryManaged, key+'data');
                    const destinationExecutable = await deployContract(walletDestination, TokenLinkerExecutableTest);
                    const sourceExecutable = await deployContract(walletSource, TokenLinkerExecutableTest);
                    const factory = new Contract(sourceChain.factory, ITokenLinkerFactory.abi, walletSource);  
                    const length = await factory.numberDeployed();
                    const id = await factory.tokenLinkerIds(length - 1);
                    let val = key + 'out';
                    let data = defaultAbiCoder.encode(['address', 'string'], [wallet.address, val]);

                    await sendTokenWithData(
                        sourceChain, 
                        destinationChain, 
                        id, 
                        factoryManaged, 
                        destinationExecutable.address, 
                        amountIn, 
                        data
                    );

                    let getBalance = tokenLinkerTypes[destination].getBalance;

                    let balance = await getBalance(destinationTokenLinker.address, wallet.address, walletDestination.provider);
                    await new Promise((resolve) => {
                        setTimeout(() => {
                            resolve();
                        }, 400);
                    });
                    balance = await getBalance(destinationTokenLinker.address, wallet.address, walletDestination.provider) - balance;
                    expect(BigInt(balance)).to.equal(BigInt(amountIn));
                    expect(await destinationExecutable.val()).to.equal(val);

                    val = key + 'in'
                    data = defaultAbiCoder.encode(['address', 'string'], [wallet.address, val]);
                    await sendTokenWithData(
                        destinationChain, 
                        sourceChain, 
                        id, 
                        factoryManaged, 
                        sourceExecutable.address,
                        amountOut, 
                        data
                    );
                    
                    getBalance = tokenLinkerTypes[source].getBalance;

                    balance = await getBalance(sourceTokenLinker.address, wallet.address, walletSource.provider);
                    await new Promise((resolve) => {
                        setTimeout(() => {
                            resolve();
                        }, 400);
                    });
                    balance = await getBalance(sourceTokenLinker.address, wallet.address, walletSource.provider) - balance;
                    expect(BigInt(balance)).to.equal(BigInt(amountOut));
                    expect(await sourceExecutable.val()).to.equal(val);
                });
            }
        }
    }
})
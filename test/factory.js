'use strict';

const chai = require('chai');
const { getDefaultProvider, Contract, Wallet, ContractFactory, constants: {AddressZero} } = require('ethers');
const { expect } = chai;
const { keccak256, defaultAbiCoder, RLP, getContractAddress } = require('ethers/lib/utils');
const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');
require('dotenv').config();

const ERC20MintableBurnable = require('../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const ITokenLinker = require('../artifacts/contracts/interfaces/ITokenLinker.sol/ITokenLinker.json');
const IERC20 = require('../artifacts/contracts/interfaces/IERC20.sol/IERC20.json');
const TokenLinker = require('../artifacts/contracts/TokenLinker.sol/TokenLinker.json');
const TokenLinkerExecutableTest = require('../artifacts/contracts/test/TokenLinkerExecutableTest.sol/TokenLinkerExecutableTest.json');
const UpgradableProxy = require('@axelar-network/axelar-gmp-sdk-solidity/artifacts/contracts/upgradables/Proxy.sol/Proxy.json');
const RemoteAddressValidator = require('../artifacts/contracts/RemoteAddressValidator.sol/RemoteAddressValidator.json');
const Deployer = require('../artifacts/contracts/Deployer.sol/Deployer.json');
const { deployContract } = require('@axelar-network/axelar-gmp-sdk-solidity/scripts/utils');
const { predictContractConstant, deployUpgradable, deployAndInitContractConstant } = require('@axelar-network/axelar-gmp-sdk-solidity');
const { createAndExport } = require('@axelar-network/axelar-local-dev');

let chains;
let wallet;

async function setupLocal(toFund) {
    await createAndExport({
        chainOutputPath: './info/local.json',
        accountsToFund: toFund,
        relayInterval: 100,
    });
}

async function deployToken(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const contract = await deployContract(wallet, ERC20MintableBurnable, ['Subnet Token', 'ST', 18]);
    chain.token = contract.address;

    return contract;
}

async function deployTokenLinker(chain) {
    const provider = getDefaultProvider(chain.rpc);
    const walletConnected = wallet.connect(provider);
    const ravAddress = await predictContractConstant(chain.constAddressDeployer, walletConnected, UpgradableProxy, 'remoteAddressValidator', []);
    
    const deployerAddress = await predictContractConstant(chain.constAddressDeployer, walletConnected, Deployer, 'deployer');
    const tlAddress = getContractAddress({from:deployerAddress, nonce:1});
    const remoteAddressValidator = await deployUpgradable(
        chain.constAddressDeployer,
        walletConnected,
        RemoteAddressValidator,
        UpgradableProxy,
        [tlAddress, [], []],
        [],
        [],
        'remoteAddressValidator',
    );
    const contractFactory = new ContractFactory(TokenLinker.abi, TokenLinker.bytecode);
    const bytecode = contractFactory.getDeployTransaction(chain.gateway, chain.gasReceiver, remoteAddressValidator.address, chain.name).data;
    const deployer = await deployAndInitContractConstant(
        chain.constAddressDeployer,
        walletConnected,
        Deployer,
        'deployer',
        [],
        [bytecode],
    );
    chain.tokenLinker = tlAddress;
    chain.remoteAddressValidator = remoteAddressValidator.address;
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
            await deployTokenLinker(chain);
        }
        setJSON(chains, './info/local.json');
        for(const chain of chains) {
            const provider = getDefaultProvider(chain.rpc);
            chain.walletConnected = wallet.connect(provider);
            chain.tl = new Contract(chain.tokenLinker, ITokenLinker.abi, chain.walletConnected);
            chain.rav = new Contract(chain.remoteAddressValidator, RemoteAddressValidator.abi, chain.walletConnected);
            chain.tok = new Contract(chain.token, ERC20MintableBurnable.abi, chain.walletConnected);
        }
    });

    it(`Should Register a Token`, async () => {
        const origin = chains[0];
        
        await (await origin.tl.registerToken(origin.token)).wait();
        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        const address = await origin.tl.getTokenAddress(tokenId);
        expect(address).to.equal(origin.token);
    });
    it(`Should deploy a remote token`, async() => {
        const origin = chains[0];
        const destination = chains[1];

        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        const receipt = await (await origin.tl.deployRemoteTokens(tokenId, [destination.name], {value: 1e7})).wait();
        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });
        expect(await destination.tl.getTokenAddress(tokenId)).to.not.equal(AddressZero);
    });
    it(`Should send some token from origin to destination`, async() => {
        const origin = chains[0];
        const destination = chains[1];
        const amount = 1e6;

        await (await origin.tok.mint(wallet.address, amount)).wait();
        await (await origin.tok.approve(origin.tl.address, amount)).wait();

        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        await (await origin.tl.sendToken(tokenId, destination.name, wallet.address, amount, {value: 1e6})).wait();
        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });
        const tokenAddr = await destination.tl.getTokenAddress(tokenId)
        const token = new Contract(tokenAddr, IERC20.abi, destination.walletConnected);
        expect(Number(await token.balanceOf(wallet.address))).to.equal(amount);
    });
    it(`Should send some token back`, async() => {
        const origin = chains[0];
        const destination = chains[1];
        const amount = 1e6;

        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        const tokenAddr = await destination.tl.getTokenAddress(tokenId)
        const token = new Contract(tokenAddr, IERC20.abi, destination.walletConnected);
        await (await token.approve(destination.tl.address, amount)).wait();

        await (await destination.tl.sendToken(tokenId, origin.name, wallet.address, amount, {value: 1e6})).wait();

        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });

        expect(Number(await origin.tok.balanceOf(wallet.address))).to.equal(amount);
    });

    it(`Should register a token and deploy a remote token in one go`, async() => {
        const origin = chains[1];
        const destination = chains[2];

        const receipt = await (await origin.tl.registerTokenAndDeployRemoteTokens(origin.token, [destination.name], {value: 1e7})).wait();
        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });
        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        expect(await destination.tl.getTokenAddress(tokenId)).to.not.equal(AddressZero);
    });
    it(`Should send some token from origin to destination`, async() => {
        const origin = chains[1];
        const destination = chains[2];
        const amount = 1e6;

        await (await origin.tok.mint(wallet.address, amount)).wait();
        await (await origin.tok.approve(origin.tl.address, amount)).wait();

        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        await (await origin.tl.sendToken(tokenId, destination.name, wallet.address, amount, {value: 1e6})).wait();
        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });
        const tokenAddr = await destination.tl.getTokenAddress(tokenId)
        const token = new Contract(tokenAddr, IERC20.abi, destination.walletConnected);
        expect(Number(await token.balanceOf(wallet.address))).to.equal(amount);
    });
    it(`Should send some token back`, async() => {
        const origin = chains[1];
        const destination = chains[2];
        const amount = 1e6;

        const tokenId = await origin.tl.getNativeTokenId(origin.token);
        const tokenAddr = await destination.tl.getTokenAddress(tokenId)
        const token = new Contract(tokenAddr, IERC20.abi, destination.walletConnected);
        await (await token.approve(destination.tl.address, amount)).wait();

        await (await destination.tl.sendToken(tokenId, origin.name, wallet.address, amount, {value: 1e6})).wait();

        await new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, 500);
        });
        
        expect(Number(await origin.tok.balanceOf(wallet.address))).to.equal(amount);
    });
})
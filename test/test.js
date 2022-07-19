'use strict';

const chai = require('chai');
const { getDefaultProvider, Contract, Wallet } = require('ethers');
const { deployTokenLinker, mint, getWallet, fundTokenLinker, sendToken } = require('../scripts');
const { expect } = chai;

const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-utils-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const { keccak256, toUtf8Bytes, defaultAbiCoder } = require('ethers/lib/utils');
const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');
const { createSubnet, fork } = require("../scripts/index");

let chains;
let avalanche;
let subnet;
let other;


describe('Token Linker', () => {
    before(async () => {
        await createSubnet();

        const testnet = require('../info/testnet.json');
        const deployer_key = keccak256(
            defaultAbiCoder.encode(
                ['string'],
                ['this is a random string to get a random account. You need to provide the private key for a funded account here.'],
            ),
        );
        const deployer_address = new Wallet(deployer_key).address;
        const toFund = [deployer_address];
        const chainsToFork = ['Subnet', 'Avalanche', 'Ethereum'];
        await fork(testnet, toFund, chainsToFork);
    
        chains = require('../info/local.json');
        avalanche = chains.find((chain) => chain.name == 'Avalanche');
        subnet = chains.find((chain) => chain.name == 'Subnet');
        other = chains.find((chain) => chain.name != 'Subnet' && chain.name != 'Avalanche');

        await deployTokenLinker(chains, new Date().getTime().toString());
        setJSON(chains, './info/local.json');
    });

    describe('Funding', () => {
        it('should mint on avalanche', async () => {
            const amount = 10n;
            
            const wallet = getWallet(avalanche);
            const token = new Contract(avalanche.token, ERC20MintableBurnable.abi, wallet);
            const balance = BigInt(await token.balanceOf(wallet.address));
            await mint(avalanche, wallet.address, amount);
            const newBalance = BigInt(await token.balanceOf(wallet.address));
            expect(newBalance - balance).to.equal(amount);
        });
        it('should fund token linker on subnet', async () => {
            const amount = 10n;
            
            const wallet = getWallet(subnet);
            const balance = BigInt(await wallet.provider.getBalance(subnet.tokenLinker));
            await fundTokenLinker(subnet, amount);
            const newBalance = BigInt(await wallet.provider.getBalance(subnet.tokenLinker));
            expect(newBalance - balance).to.equal(amount);
        });
    });

    describe('Sending', () => {
        const amount = 10n;
        const fundAmount = 2n * amount;
        before(async () => {
            for(const chain of [avalanche, other]) {
                const wallet = getWallet(chain);
                const token = new Contract(chain.token, ERC20MintableBurnable.abi, wallet);
                const balance = BigInt(await token.balanceOf(wallet.address));
                await mint(chain, wallet.address, fundAmount);
                const newBalance = BigInt(await token.balanceOf(wallet.address));
                expect(newBalance - balance).to.equal(fundAmount);
            }
            const wallet = getWallet(subnet);
            const balance = BigInt(await wallet.provider.getBalance(subnet.tokenLinker));
            await fundTokenLinker(subnet, fundAmount);
            const newBalance = BigInt(await wallet.provider.getBalance(subnet.tokenLinker));
            expect(newBalance - balance).to.equal(fundAmount);
        });
        for(const fromChain of [avalanche, subnet, other]) {
            for(const toChain of [avalanche, subnet, other]) {
                if(fromChain == toChain) continue;
                it(`should send token from ${fromChain.name} to ${toChain.name}`, async () => {    
                    const getBalance = async(address) => {
                        const providerTo = getDefaultProvider(toChain.rpc);
                        if(toChain.name == 'Subnet') return BigInt(await providerTo.getBalance(address));
                        const token = new Contract(toChain.token, ERC20MintableBurnable.abi, providerTo);
                        return BigInt(await token.balanceOf(address));
                    }
                    const address = new Wallet(keccak256(toUtf8Bytes('this will be sent to.'))).address;
                    const balance = await getBalance(address);
                    await sendToken(fromChain, toChain, address, amount, 1);
                    const newBalance = await getBalance(address);
                    expect(newBalance - balance).to.equal(amount);
                });
            }
        }
    })
})
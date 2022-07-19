'use strict';

const chai = require('chai');
const { getDefaultProvider, Contract, Wallet } = require('ethers');
const { deployTokenLinker, mint, getWallet, fundTokenLinker, sendToken } = require('../scripts');
const { expect } = chai;

const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-utils-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const { keccak256, toUtf8Bytes } = require('ethers/lib/utils');
const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');

let chains;
try {
    chains = require('../info/local.json');
} catch(e) {
    console.log(e);
    throw new Error('Should fork before testing.');
}
const avalanche = chains.find((chain) => chain.name == 'Avalanche');
const subnet = chains.find((chain) => chain.name == 'Subnet');
const other = chains.find((chain) => chain.name != 'Subnet' && chain.name != 'Avalanche');

describe('Token Linker', () => {
    before(async () => {
        let toDeploy = false;
        try {
            for(const chain in chains) {
                const provider = getDefaultProvider(chain.rpc);
                const n = await provider.getBlockNumber();
                if(!chain.tokenLinker) toDeploy = true;
            }
        } catch(e) {
            console.log(e);
            throw new Error('Should fork before testing.');
        }
        if(toDeploy) await deployTokenLinker(chains, new Date().getTime().toString());
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
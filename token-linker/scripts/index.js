const { Contract, getDefaultProvider, Wallet } = require("ethers");
const { deployUpgradable, upgradeUpgradable } = require('@axelar-network/axelar-utils-solidity');
const { createNetwork, forkAndExport } = require('@axelar-network/axelar-local-dev');
const { keccak256, defaultAbiCoder, toUtf8Bytes } = require('ethers/lib/utils');
const { setJSON, deployContract } = require('@axelar-network/axelar-utils-solidity/scripts/utils');
const axios = require('axios');

const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-utils-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');
const TokenLinkerProxy = require('../artifacts/@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerProxy.sol/TokenLinkerProxy.json');
const TokenLinkerNative = require('../artifacts/contracts/TokenLinkerNative.sol/TokenLinkerNative.json');
const TokenLinkerLockUnlock = require('../artifacts/contracts/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const TokenLinkerMintBurn = require('../artifacts/contracts/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const TokenLinker = require('../artifacts/contracts/TokenLinker.sol/TokenLinker.json');
const ConstAddressDeployer = require('@axelar-network/axelar-utils-solidity/dist/ConstAddressDeployer.json');

const deployer_private_key = keccak256(toUtf8Bytes(`constAddressDeployer deployer key`));


const tokenLinkers = {
    'Subnet': {
        name: 'Native',
        contractJson: TokenLinkerNative,
    },
    'Avalanche': {
        name: 'Lock/Unlock',
        contractJson: TokenLinkerLockUnlock,
    },
    'Other': {
        name: 'Mint/Burn',
        contractJson: TokenLinkerMintBurn,
    },
}

function getWallet(chain) {
    const deployer_key = keccak256(
        defaultAbiCoder.encode(
            ['string'],
            ['this is a random string to get a random account. You need to provide the private key for a funded account here.'],
        ),
    );
    const provider = getDefaultProvider(chain.rpc);
    return new Wallet(deployer_key, provider);
}

async function createSubnet() {
    const subnet = await createNetwork({
        name: 'Subnet',
        port: 8501,
    });

    const info = subnet.getCloneInfo();
    info.rpc = 'http://localhost:8501',
    info.tokenName = 'Sunbet Token';
    info.tokenSymbol = 'ST';
    info.constAddressDeployer = null;

    const wallet = getWallet(info);
    const [user] = subnet.userWallets;
    user.sendTransaction({
        to: wallet.address,
        value: BigInt(1e18),
    }).then((tx) => tx.wait());
    
    await deployConstAddressDeployer([info], wallet);

    const testnetInfo = require('../info/testnet.json');
    const index = testnetInfo.findIndex((chain) => chain.name == 'Subnet');
    if(index == -1) {
        testnetInfo.push(info);
    } else {
        testnetInfo[index] = info;
    }
    setJSON(testnetInfo, './info/testnet.json');
}

async function fork(chains, toFund = [], chainsToFork = ['Subnet', 'Avalanche', 'Ethereum']) {
    await forkAndExport({
        chainOutputPath: './info/local.json',
        env: chains,
        chains: chainsToFork,
        accountsToFund: toFund,
    }, {
        ganacheOptions: {
            fork: { disableCache: true },
        }
    });
}

async function deployTokenLinker(chains, key = 'token-linker') {
    for (const chain of chains) {
        const wallet = getWallet(chain);
        const name = tokenLinkers[chain.name] ? chain.name : 'Other';
        console.log(`Deploying a ${tokenLinkers[name].name} token linker for ${chain.name}`);
        const implContractJson = tokenLinkers[name].contractJson;

        const args = [chain.gateway, chain.gasReceiver];
        if (name != 'Subnet') {
            if(!chain.token) {
                await deployToken(chain, wallet);
            }
            args.push(chain.token);
        }
        const contract = await deployUpgradable(
            chain.constAddressDeployer,
            wallet,
            implContractJson,
            TokenLinkerProxy,
            args,
            [],
            '0x',
            key
        );
        console.log(`Deployed at ${contract.address}.`);
        chain.tokenLinker = contract.address;
        if(!chain.token) {
            const token = await deployToken(chain, wallet);
            chain.token = token.address;
        }
    }
}

async function upgradeTokenLinker(chains) {
    for (const chain of chains) {
        if(!chain.tokenLinker) continue;
        const wallet = getWallet(chain);
        const name = tokenLinkers[chain.name] ? chain.name : 'Other';
        if(!chain.token) {
            const token = await deployToken(chain, wallet);
            chain.token = token.address;
        }
        console.log(`Upgrading token linker (${chain.tokenLinker}) for ${chain.name}`);
        const implContractJson = tokenLinkers[name].contractJson;

        const args = [chain.gateway, chain.gasReceiver];
        if (name != 'Subnet') args.push(chain.token);
        await upgradeUpgradable(
            chain.tokenLinker,
            wallet,
            implContractJson,
            args,
            '0x',
        );
    }
}

async function deployConstAddressDeployer(chains) {
    for (const chain of chains) {
        if(chain.constAddressDeployer) continue;
        const wallet = getWallet(chain);
        const deployerWallet = new Wallet(deployer_private_key, wallet.provider);

        await (await wallet.sendTransaction({
            to: deployerWallet.address,
            value: BigInt(1e17)
        })).wait();

        const contract = await deployContract(deployerWallet, ConstAddressDeployer);
        console.log(`Deployed for ${chain.name} at ${contract.address}.`);
        chain.constAddressDeployer = contract.address;
    }
}

async function deployToken (chain) {
    const wallet = getWallet(chain);
    console.log(`Deploying token for ${chain.name}.`);
    //This is deployed at 0xC155E918c5aBBa6B020010a253981B2Cbd9e4844 on Avalanche Fuji
    const contract = await deployContract(wallet, ERC20MintableBurnable, ['Subnet Token', 'ST', 18]);
    console.log(`Deployed at ${contract.address}.`);
    chain.token = contract.address;

    return contract
    // On Fantom at 0x0CdB797280bEAa14C4BBc115272bbd92C6C80ED3
    // On Ethereum at 0x30EB0faBa5eeB889F4492289cc3A290EaC3f0553
}

async function mint(chain, to, amount) {
    const wallet = getWallet(chain)
    console.log(`Minting ${amount} tokens (${chain.token}) to ${to} at ${chain.name}`);
    const token = new Contract(chain.token, ERC20MintableBurnable.abi, wallet);
    await (await token.mint(to, amount)).wait();
}

async function fundTokenLinker(chain, amount) {
    const wallet = getWallet(chain);
    console.log(`Transfering ${amount} ${chain.tokenSymbol} to ${chain.tokenLinker} at ${chain.name}`);
    const tokenLinker = new Contract(chain.tokenLinker, TokenLinkerNative.abi, wallet);
    await (await tokenLinker.updateBalance({value: amount})).wait();
}

async function getGasPrice(env, source, destination, tokenAddress) {
    if(env == 'local') return 1;
    if(env != 'testnet') throw Error('env needs to be "local" or "testnet".');
    const api_url ='https://devnet.api.gmp.axelarscan.io';

    const requester = axios.create({ baseURL: api_url });
        const params = {
        method: 'getGasPrice',
        destinationChain: destination.name,
        sourceChain: source.name,
    };

    // set gas token address to params
    if (tokenAddress != AddressZero) {
        params.sourceTokenAddress = tokenAddress;
    }
    else {
        params.sourceTokenSymbol = source.tokenSymbol;
    }
      // send request
    const response = await requester.get('/', { params })
        .catch(error => { return { data: { error } }; });
    const result = response.data.result;
    const dest = result.destination_native_token;
    const destPrice = 1e18*dest.gas_price*dest.token_price.usd;
    return destPrice / result.source_token.token_price.usd;
}

async function sendToken(fromChain, toChain, to, amount, gasPrice) {
    const wallet = getWallet(fromChain);
    const tokenLinker = new Contract(fromChain.tokenLinker, TokenLinker.abi, wallet);
    
    const getBalance = async() => {
        const providerTo = getDefaultProvider(toChain.rpc);
        if(toChain.name == 'Subnet') return BigInt(await providerTo.getBalance(to));
        const token = new Contract(toChain.token, ERC20MintableBurnable.abi, providerTo);
        return BigInt(await token.balanceOf(to));
    }

    const balance = await getBalance();
    const gasLimit = 1e6;
    
    if(fromChain.name == 'Subnet') {
        console.log(`Sending ${amount} of token ${fromChain.token} to ${toChain.name} with a gas price of ${gasPrice}.`);
        await (await tokenLinker.sendToken(toChain.name, to, amount, {value: BigInt(gasPrice) * BigInt(gasLimit) + BigInt(amount)})).wait();
    } else {
        const tokenFrom = new Contract(fromChain.token, ERC20MintableBurnable.abi, wallet);
        console.log(`Approving ${amount} of token ${fromChain.token} on ${fromChain.name}`);
        await (await tokenFrom.approve(tokenLinker.address, amount)).wait();
        console.log(`Sending ${amount} of token ${fromChain.token} to ${toChain.name} with a gas price of ${gasPrice}.`);
        await (await tokenLinker.sendToken(toChain.name, to, amount, {value: gasPrice * gasLimit})).wait();
    }
    function sleep(ms) {
        return new Promise((resolve) => {
            setTimeout(() => {
                resolve();
            }, ms);
        });
    }

    let newBalance = await getBalance();
    while(newBalance == balance) {
        await sleep(2000);
        newBalance = await getBalance();
    }
}

module.exports = {
    createSubnet,
    getGasPrice,
    fork,
    deployConstAddressDeployer,
    deployToken,
    deployTokenLinker,
    upgradeTokenLinker,
    mint,
    fundTokenLinker,
    sendToken,
    getWallet,
}
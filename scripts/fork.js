const {
    Wallet,
    utils: { keccak256, defaultAbiCoder },
} = require('ethers');
const { fork } = require('.');

const env = process.argv[2];
const chains = require(`../info/${env}.json`);

const deployerKey = keccak256(
    defaultAbiCoder.encode(
        ['string'],
        ['this is a random string to get a random account. You need to provide the private key for a funded account here.'],
    ),
);
const deployerAddress = new Wallet(deployerKey).address;
const toFund = [deployerAddress];
const rest = process.argv.slice(3);
const chainsToFork = rest.length === 0 ? ['Subnet', 'Avalanche', 'Ethereum'] : rest;
fork(chains, toFund, chainsToFork);

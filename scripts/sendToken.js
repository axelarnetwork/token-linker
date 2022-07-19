'use strict';

const { testnetInfo } = require('@axelar-network/axelar-local-dev');
const {
    constants: { AddressZero },
} = require('ethers');
const { getGasPrice, sendToken, getWallet } = require('.');

const env = process.argv[2];
if (env === null || (env !== 'testnet' && env !== 'local'))
    throw new Error('Need to specify tesntet or local as an argument to this script.');
let temp;

if (env === 'local') {
    temp = require(`../info/local.json`);
} else {
    try {
        temp = require(`../info/testnet.json`);
    } catch {
        temp = testnetInfo;
    }
}

const chains = temp;
const from = process.argv[3] || 'Avalanche';
const to = process.argv[4] || 'Subnet';
const destinationAddress = process.argv[5] || getWallet(to).address;
const amount = process.argv[6] || 10;

const fromChain = chains.find((chain) => chain.name === from);
const toChain = chains.find((chain) => chain.name === to);

getGasPrice(env, from, to, AddressZero).then((gasPrice) => {
    sendToken(fromChain, toChain, destinationAddress, amount, gasPrice);
});

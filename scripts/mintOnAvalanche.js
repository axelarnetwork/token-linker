'use strict';

const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');
const { mint, deployToken, fundTokenLinker, getWallet } = require('.');

const env = process.argv[2];
if (env === null || (env !== 'testnet' && env !== 'local'))
    throw new Error('Need to specify tesntet or local as an argument to this script.');
const chains = require(`../info/${env}.json`);

const chain = chains.find((chain) => chain.name === 'Avalanche');

const subnet = chains.find((chain) => chain.name === 'Subnet');

const wallet = getWallet(chain);

const to = process.argv[3] || wallet.address;

const amount = process.argv[4] || 1e6;

(async () => {
    if (!chain.token) {
        await deployToken(chain, wallet);
        setJSON(chains, `./info/${env}.json`);
    }

    await mint(chain, to, amount);

    await fundTokenLinker(subnet, amount);
})();

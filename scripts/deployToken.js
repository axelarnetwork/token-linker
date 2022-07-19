const { setJSON } = require('@axelar-network/axelar-local-dev/dist/utils');
const { deployToken } = require('.');

const env = process.argv[2];
if (env === null || (env !== 'testnet' && env !== 'local'))
    throw new Error('Need to specify tesntet or local as an argument to this script.');
const chains = require(`../info/${env}.json`);

const chainName = process.argv[3] || 'Avalanche';

const chain = chains.find((chain) => chain.name === chainName);

deployToken(chain).then(() => setJSON(chains, `./info/${env}.json`));

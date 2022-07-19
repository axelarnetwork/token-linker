'use strict';

const {
    utils: { setJSON },
} = require('@axelar-network/axelar-local-dev');

const { deployTokenLinker } = require('.');

const env = process.argv[2];
if (env === null || (env !== 'testnet' && env !== 'local'))
    throw new Error('Need to specify tesntet or local as an argument to this script.');
const chains = require(`../info/${env}.json`);

deployTokenLinker(chains).then(() => setJSON(chains, `./info/${env}.json`));

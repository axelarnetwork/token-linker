'use strict';

const {
    utils: { setJSON },
} = require('@axelar-network/axelar-local-dev');
const { deployConstAddressDeployer } = require('.');

const env = process.argv[2];

const chains = require(`../info/${env}.json`);

deployConstAddressDeployer(env, chains).then(() => {
    setJSON(chains, `./info/${env}.json`);
})

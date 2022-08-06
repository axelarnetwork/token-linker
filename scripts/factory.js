const { deployAndInitContractConstant } = require("@axelar-network/axelar-utils-solidity");
const { getDefaultProvider } = require("ethers");
const { createAndExport } = require("@axelar-network/axelar-local-dev");
const { deployContract } = require("@axelar-network/axelar-utils-solidity/scripts/utils");
const { keccak256 } = require("ethers/lib/utils");

const TokenLinkerFactory = require('../artifacts/contracts/TokenLinkerFactory.sol/TokenLinkerFactory.json');
const LockUnlock = require('../artifacts/contracts/token-linkers/TokenLinkerLockUnlock.sol/TokenLinkerLockUnlock.json');
const MintBurn = require('../artifacts/contracts/token-linkers/TokenLinkerMintBurn.sol/TokenLinkerMintBurn.json');
const MintBurnExternal = require('../artifacts/contracts/token-linkers/TokenLinkerMintBurnExternal.sol/TokenLinkerMintBurnExternal.json');
const Native = require('../artifacts/contracts/token-linkers/TokenLinkerNative.sol/TokenLinkerNative.json');
const Proxy = require('../artifacts/contracts/token-linkers/TokenLinkerFactoryLookupProxy.sol/TokenLinkerFactoryLookupProxy.json');
const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-utils-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');

async function setupLocal(toFund) {
    await createAndExport(
        {
            chainOutputPath: './info/local.json',
            accountsToFund: toFund,
        },
    );
}

async function deploy(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc)
    const wallet = walletUnconnected.connect(provider);
    const impl = [];
    console.log(`Deploying implementations on ${chain.name}.`)
    
    for(const contractJson of [LockUnlock, MintBurn, MintBurnExternal, Native]) {
        impl.push(
            (await deployContract(
                wallet, 
                contractJson, 
                [chain.gateway, chain.gasReceiver]
            )).address
        );
    }
    console.log('Done. Deploying Factory')
    const bytecode = Proxy.bytecode;
    const codehash = keccak256(bytecode);
    const factory = await deployAndInitContractConstant(
        chain.constAddressDeployer,
        wallet, 
        TokenLinkerFactory,
        'factory', 
        [codehash], 
        [impl, chain.gateway, chain.gasReceiver],
        4e6,
    );
    console.log(`Deployed at ${factory.address}.`)
    chain.factory = factory.address;
}

async function deployToken(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const contract = await deployContract(wallet, ERC20MintableBurnable, ['Subnet Token', 'ST', 18]);
    chain.token = contract.address;

    return contract;
}

module.exports = {
    setupLocal,
    deploy,
    deployToken,
}

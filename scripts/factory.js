const { deployAndInitContractConstant, deployUpgradable } = require('@axelar-network/axelar-gmp-sdk-solidity');
const { getDefaultProvider } = require('ethers');
const { createAndExport } = require('@axelar-network/axelar-local-dev');
const { deployContract } = require('@axelar-network/axelar-gmp-sdk-solidity/scripts/utils');
const { keccak256, defaultAbiCoder } = require('ethers/lib/utils');

const TokenLinkerFactory = require('../artifacts/contracts/TokenLinkerFactory.sol/TokenLinkerFactory.json');
const TokenLinkerFactoryProxy = require('../artifacts/contracts/TokenLinkerFactoryProxy.sol/TokenLinkerFactoryProxy.json');
const LockUnlockFM = require('../artifacts/contracts/token-linkers/TokenLinkersFactoryLookup.sol/TokenLinkerLockUnlockFactoryLookup.json');
const MintBurnFM = require('../artifacts/contracts/token-linkers/TokenLinkersFactoryLookup.sol/TokenLinkerMintBurnFactoryLookup.json');
const MintBurnExternalFM = require('../artifacts/contracts/token-linkers/TokenLinkersFactoryLookup.sol/TokenLinkerMintBurnExternalFactoryLookup.json');
const NativeFM = require('../artifacts/contracts/token-linkers/TokenLinkersFactoryLookup.sol/TokenLinkerNativeFactoryLookup.json');

const LockUnlockU = require('../artifacts/contracts/token-linkers/TokenLinkersUpgradable.sol/TokenLinkerLockUnlockUpgradable.json');
const MintBurnU = require('../artifacts/contracts/token-linkers/TokenLinkersUpgradable.sol/TokenLinkerMintBurnUpgradable.json');
const MintBurnExternalU = require('../artifacts/contracts/token-linkers/TokenLinkersUpgradable.sol/TokenLinkerMintBurnExternalUpgradable.json');
const NativeU = require('../artifacts/contracts/token-linkers/TokenLinkersUpgradable.sol/TokenLinkerNativeUpgradable.json');

const ProxyFM = require('../artifacts/contracts/token-linkers/TokenLinkerFactoryLookupProxy.sol/TokenLinkerFactoryLookupProxy.json');
const ProxyU = require('../artifacts/contracts/token-linkers/TokenLinkerSelfLookupProxy.sol/TokenLinkerSelfLookupProxy.json');
const ERC20MintableBurnable = require('../artifacts/@axelar-network//axelar-gmp-sdk-solidity/contracts/test/ERC20MintableBurnable.sol/ERC20MintableBurnable.json');

async function setupLocal(toFund) {
    await createAndExport({
        chainOutputPath: './info/local.json',
        accountsToFund: toFund,
        relayInterval: 100,
    });
}

async function deploy(chain, walletUnconnected) {
    const provider = getDefaultProvider(chain.rpc);
    const wallet = walletUnconnected.connect(provider);
    const factoryManaged = [];
    const upgradable = [];
    console.log(`Deploying implementations on ${chain.name}.`);

    for (const contractJson of [LockUnlockFM, MintBurnFM, MintBurnExternalFM, NativeFM]) {
        factoryManaged.push((await deployContract(wallet, contractJson, [chain.gateway, chain.gasReceiver])).address);
    }

    for (const contractJson of [LockUnlockU, MintBurnU, MintBurnExternalU, NativeU]) {
        upgradable.push((await deployContract(wallet, contractJson, [chain.gateway, chain.gasReceiver])).address);
    }

    console.log('Done. Deploying Factory');
    const bytecodeFM = ProxyFM.bytecode;
    const codehashFM = keccak256(bytecodeFM);
    const bytecodeU = ProxyU.bytecode;
    const codehashU = keccak256(bytecodeU);

    const factory = await deployUpgradable(
        chain.constAddressDeployer,
        wallet,
        TokenLinkerFactory,
        TokenLinkerFactoryProxy,
        [codehashFM, codehashU, chain.gateway, chain.gasReceiver],
        [],
        defaultAbiCoder.encode(['address[]', 'address[]'], [factoryManaged, upgradable]),
        'factory',
    );
    console.log(`Deployed at ${factory.address}.`);
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
};

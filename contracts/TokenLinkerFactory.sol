// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerProxy } from './proxies/TokenLinkerProxy.sol';
import { ITokenLinkerFactory } from './interfaces/ITokenLinkerFactory.sol';
import { ITokenLinker } from './interfaces/ITokenLinker.sol';
import { IOwnable } from './interfaces/IOwnable.sol';
import { Upgradable } from './proxies/Upgradable.sol';
import { Proxied } from './proxies/Proxied.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';
import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/StringAddressUtils.sol';
import { VersionManagement } from './libraries/VersionManagement.sol';

contract TokenLinkerFactory is ITokenLinkerFactory, AxelarExecutable, Upgradable {
    using StringToAddress for string;
    using AddressToString for address;
    using VersionManagement for bytes32;

    struct RemoteDeploymentData {
        string chainName;
        uint256 tlt;
        bytes params;
        uint256 gasAmount;
    }

    IAxelarGasService public immutable gasService;
    address public gatewayAddress;

    bytes32 public immutable proxyCodehash;

    uint256 public constant tltNumber = 4;

    bytes32 public constant TOKEN_LINKER_ID_SALT = 0x499cfb677d55923bebc1cd795449c197c05b0c2a467e4a06cff4c786bc31f35e;
    // bytes32(uint256(keccak256('token-linker-factory')) - 1)
    bytes32 public constant override contractId = 0xa6c51be88107847c935460e49bbd180f046b860284d379b474442c02536eabe8;
    // uint256(keccak256('implementation-slot-salt')) - 1
    uint256 public constant IMPLEMENTATION_SLOT_MASK = 0x89eeec7092890331abf71a989f3da1ef481b3c66af66b7eefcbd3334371285f0;

    bytes32[] public override tokenLinkerIds;
    mapping(bytes32 => TokenLinkerType) public override tokenLinkerTypes;

    address public immutable latestLockUnlock; 
    address public immutable latestMintBurn;
    address public immutable latestMintBurnExternal;
    address public immutable latestNative;

    uint256 public immutable override latestVersion;

    bytes public override deployingData;

    constructor(
        bytes32 proxyCodehash_, 
        address gatewayAddress_,
        address gasServiceAddress_,
        uint256 latestVersion_,
        address[] memory implementations
    ) AxelarExecutable(gatewayAddress_){
        if (gasServiceAddress_ == address(0)) revert ZeroAddress();
        gasService = IAxelarGasService(gasServiceAddress_);
        proxyCodehash = proxyCodehash_;
        latestVersion = latestVersion_;
        if(implementations.length != tltNumber) revert LengthMismatch();
        for (uint256 i; i < tltNumber; ++i) {
            _checkImplementation(implementations[i], TokenLinkerType(i));
        }
        latestLockUnlock = implementations[0];
        latestMintBurn = implementations[1];
        latestMintBurnExternal = implementations[2];
        latestNative = implementations[3];
    }

    function getSlot(TokenLinkerType tlt, uint256 version) internal pure returns(uint256 slot) {
        slot = uint256(keccak256(abi.encode(IMPLEMENTATION_SLOT_MASK, tlt))) + version;
    }

    function _setup(bytes calldata data) internal override {
        address[][] memory implementations = abi.decode(data, (address[][]));
        uint256 length = implementations.length;
        if(length != tltNumber) revert LengthMismatch();
        for (uint256 tlt; tlt < length; ++tlt) {
            uint256 length2 = implementations[tlt].length;
            if(length2 != latestVersion + 1) revert LengthMismatch();
            for (uint256 version; version < length2; ++version) {
                address impl = implementations[tlt][version];
                //if we add another token linker type in the future uncomment the below since not all versions will exist.
                //if(impl == address(0)) continue;
                _checkImplementation(impl, TokenLinkerType(tlt));
                _setImplementation(TokenLinkerType(tlt), version, impl);
            }
        }
    }

    function _checkImplementation(address implementation, TokenLinkerType tlt) internal view {
        uint256 size;
        assembly {
            size := extcodesize(implementation)
        }
        if (size == 0) revert ImplementationIsNotContract();
        if (ITokenLinker(implementation).implementationType() != tlt) revert WrongTokenLinkerType();
    }

    function getTokenLinkerId(address creator, bytes32 salt) public pure override returns (bytes32 id) {
        id = keccak256(abi.encode(TOKEN_LINKER_ID_SALT, salt, creator));
    }

    function numberDeployed() external view override returns (uint256) {
        return tokenLinkerIds.length;
    }

    function _deploy(
        TokenLinkerType tlt,
        bytes32 versionManagement,
        bytes32 id,
        bytes memory params
    ) internal {
        address proxyAddress;
        deployingData = abi.encode(tlt, versionManagement);
        TokenLinkerProxy proxy = new TokenLinkerProxy{ salt: id }();
        deployingData = new bytes(0);
        address owner = address(this);
        if(!versionManagement.isFactoryManaged()) owner = msg.sender;
        proxy.init(owner, params);
        tokenLinkerIds.push(id);
        tokenLinkerTypes[id] = tlt;
        emit TokenLinkerDeployed(tlt, versionManagement, id, params, proxyAddress);
    }

    function deploy(
        TokenLinkerType tlt,
        bytes32 versionManagement,
        bytes32 salt,
        bytes calldata params
    ) external override notFrozen {
        bytes32 id = getTokenLinkerId(msg.sender, salt);
        _deploy(tlt, versionManagement, id, params);
    }

    function deployMultichain(
        TokenLinkerType tlt,
        bytes32 versionManagement,
        bytes32 salt,
        bytes calldata params,
        RemoteDeploymentData[] calldata rdd
    ) external notFrozen {
        // This is the id after this point. We don't use another local variable to avoid stack_too_deep.
        salt = getTokenLinkerId(msg.sender, salt);
        _deploy(tlt, versionManagement, salt, params);
        uint256 length = rdd.length;
        string memory thisAddress = address(this).toString();
        for (uint256 i; i < length; ++i) {
            bytes memory payload = abi.encode(salt, versionManagement, rdd[i].tlt, rdd[i].params);
            uint256 gasAmount = rdd[i].gasAmount;
            string memory chain = rdd[i].chainName;
            if (gasAmount < address(this).balance) revert InsufficientAmountForGas();
            if (gasAmount > 0) {
                gasService.payNativeGasForContractCall{ value: gasAmount }(address(this), chain, thisAddress, payload, msg.sender);
            }
            gateway.callContract(chain, thisAddress, payload);
        }
    }

    function _getAddress(bytes32 id, bytes32 codeHash) internal view returns (address deployedAddress_) {
        deployedAddress_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            address(this),
                            id,
                            codeHash // init code hash
                        )
                    )
                )
            )
        );
    }

    function tokenLinker(bytes32 id) public view override returns (address tokenLinkerAddress) {
        tokenLinkerAddress = _getAddress(id, proxyCodehash);
    }

    function _execute (
        string calldata, /*sourceChain*/
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override notFrozen {
        if (sourceAddress.toAddress() != address(this)) revert WrongSourceCaller();
        (bytes32 id, TokenLinkerType tlt, bytes32 versionManagement, bytes memory params) = abi.decode(payload, (bytes32, TokenLinkerType, bytes32, bytes));
        _deploy(tlt, versionManagement, id, params);
    }

    function getImplementation(TokenLinkerType tlt, uint256 version) external view returns (address impl) {
        if(version > latestVersion) revert('InvalidVersion()');
        uint256 slot = getSlot(tlt, version);
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(TokenLinkerType tlt, uint256 version, address impl) internal {
        uint256 slot = getSlot(tlt, version);
        assembly {
            sstore(slot, impl)
        }
    }

    function getLatestImplementation(TokenLinkerType tlt) external view returns (address) {
        if(tlt == TokenLinkerType.lockUnlock) return latestLockUnlock;
        if(tlt == TokenLinkerType.mintBurn) return latestMintBurn;
        if(tlt == TokenLinkerType.mintBurnExternal) return latestMintBurnExternal;
        return latestNative;
    }

    function upgradeTokenLinkers(bytes32[] calldata ids, bytes[] calldata params) external onlyOwner {
        uint256 length = ids.length;
        if(length != params.length) revert ArrayLengthMismatch();

        for(uint256 i; i<length; ++i) {
            address tl = tokenLinker(ids[i]);
            ITokenLinker(tl).upgrade(latestVersion, params[i]);
        }
    }
}

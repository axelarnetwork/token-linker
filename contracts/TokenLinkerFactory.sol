// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinkerFactoryLookupProxy } from './token-linkers/TokenLinkerFactoryLookupProxy.sol';
import { TokenLinkerSelfLookupProxy } from './token-linkers/TokenLinkerSelfLookupProxy.sol';
import { ITokenLinkerFactory } from './interfaces/ITokenLinkerFactory.sol';
import { ITokenLinker } from './interfaces/ITokenLinker.sol';
import { IOwnable } from './interfaces/IOwnable.sol';
import { Upgradable } from './proxies/Upgradable.sol';
import { Proxied } from './proxies/Proxied.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';
import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/StringAddressUtils.sol';

contract TokenLinkerFactory is ITokenLinkerFactory, AxelarExecutable, Proxied, Upgradable {
    using StringToAddress for string;
    using AddressToString for address;

    struct RemoteDeploymentData {
        string chainName;
        uint256 tlt;
        bytes params;
        uint256 gasAmount;
    }

    address[] public override factoryManagedImplementations;
    address[] public override upgradableImplementations;

    IAxelarGasService public immutable gasService;
    address public gatewayAddress;

    bytes32 public immutable factoryManagedProxyCodehash;
    bytes32 public immutable upgradableProxyCodehash;

    bytes32 public constant TOKEN_LINKER_ID_SALT = 0x499cfb677d55923bebc1cd795449c197c05b0c2a467e4a06cff4c786bc31f35e;
    // bytes32(uint256(keccak256('token-linker-factory')) - 1)
    bytes32 public constant override contractId = 0xa6c51be88107847c935460e49bbd180f046b860284d379b474442c02536eabe8;

    bytes32[] public override tokenLinkerIds;
    mapping(bytes32 => uint256) public override tokenLinkerType;

    constructor(
        bytes32 factoryManagedProxyCodehash_, 
        bytes32 upgradableProxyCodehash_, 
        address gatewayAddress_,
        address gasServiceAddress_
    ) AxelarExecutable(gatewayAddress_){
        if (gasServiceAddress_ == address(0)) revert ZeroAddress();
        gasService = IAxelarGasService(gasServiceAddress_);
        factoryManagedProxyCodehash = factoryManagedProxyCodehash_;
        upgradableProxyCodehash = upgradableProxyCodehash_;
    }

    function _setup(bytes calldata data) internal override {
        (
            address[] memory factoryManagedImplementations_,
            address[] memory upgradableImplementations_
        ) = abi.decode(data, (address[], address[]));
        uint256 length = factoryManagedImplementations_.length;
        if(length != upgradableImplementations_.length) revert LengthMismatch();
        for (uint256 i; i < length; ++i) {
            _checkImplementation(factoryManagedImplementations_[i], i);
            _checkImplementation(upgradableImplementations_[i], i);
        }
        factoryManagedImplementations = factoryManagedImplementations_;
        upgradableImplementations = upgradableImplementations_;
    }

    function _checkImplementation(address implementation, uint256 tlt) internal view {
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
        uint256 tlt,
        bytes32 id,
        bytes memory params,
        bool factoryManaged
    ) internal {
        address proxyAddress;
        if (factoryManaged) {
            TokenLinkerFactoryLookupProxy proxy = new TokenLinkerFactoryLookupProxy{ salt: id }();
            proxy.init(tlt, params);
            proxyAddress = address(proxy);
        } else {
            TokenLinkerSelfLookupProxy proxy = new TokenLinkerSelfLookupProxy{ salt: id }();
            proxy.init(upgradableImplementations[tlt], msg.sender, params);
            proxyAddress = address(proxy);
        }
        tokenLinkerIds.push(id);
        tokenLinkerType[id] = tlt;
        emit TokenLinkerDeployed(tlt, id, params, factoryManaged, proxyAddress);
    }

    function deploy(
        uint256 tlt,
        bytes32 salt,
        bytes calldata params,
        bool factoryManaged
    ) external override {
        bytes32 id = getTokenLinkerId(msg.sender, salt);
        _deploy(tlt, id, params, factoryManaged);
    }

    function deployMultichain(
        uint256 tlt,
        bytes32 salt,
        bytes calldata params,
        bool factoryManaged,
        RemoteDeploymentData[] calldata rdd
    ) external {
        // This is the id after this point. We don't use another local variable to avoid stack_too_deep.
        salt = getTokenLinkerId(msg.sender, salt);
        _deploy(tlt, salt, params, factoryManaged);
        uint256 length = rdd.length;
        string memory thisAddress = address(this).toString();
        for (uint256 i; i < length; ++i) {
            bytes memory payload = abi.encode(salt, rdd[i].tlt, rdd[i].params, factoryManaged);
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

    function tokenLinker(bytes32 id, bool factoryManaged) public view override returns (address tokenLinkerAddress) {
        bytes32 codeHash;
        if (factoryManaged) {
            codeHash = factoryManagedProxyCodehash;
        } else {
            codeHash = upgradableProxyCodehash;
        }
        tokenLinkerAddress = _getAddress(id, codeHash);
    }

    function _execute(
        string calldata, /*sourceChain*/
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        if (sourceAddress.toAddress() != address(this)) revert WrongSourceCaller();
        (bytes32 id, uint256 tlt, bytes memory params, bool factoryManaged) = abi.decode(payload, (bytes32, uint256, bytes, bool));
        _deploy(tlt, id, params, factoryManaged);
    }
}

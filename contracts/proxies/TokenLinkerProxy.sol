// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { Proxy } from './Proxy.sol';
import { Ownable } from '../utils/Ownable.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';
import { ITokenLinkerProxy } from '../interfaces/ITokenLinkerProxy.sol';
import { VersionManagement } from '../libraries/VersionManagement.sol';
import { VersionManaged } from '../versioning/VersionManaged.sol';

contract TokenLinkerProxy is ITokenLinkerProxy, Proxy, VersionManaged {
    using VersionManagement for bytes32;

    address public immutable override factory;
    ITokenLinkerFactory.TokenLinkerType public immutable override tokenLinkerType;
    bool public immutable override factoryManaged;

    // bytes32(uint256(keccak256('token-linker')) - 1)
    bytes32 public constant override contractId = 0x6ec6af55bf1e5f27006bfa01248d73e8894ba06f23f8002b047607ff2b1944ba;

    function implementation() public view override returns (address implementation_) {
        // solhint-disable-next-line no-inline-assembly
        if(factoryManaged) {
            implementation_ = ITokenLinkerFactory(factory).getLatestImplementation(tokenLinkerType);
        } else {
            assembly {
                implementation_ := sload(_IMPLEMENTATION_SLOT)
            }
        }
    }

    constructor() {
        factory = msg.sender;
        bytes32 versionManagement;
        bytes memory data = ITokenLinkerFactory(factory).deployingData();
        (tokenLinkerType, versionManagement) = abi.decode(data, (ITokenLinkerFactory.TokenLinkerType, bytes32));
        factoryManaged = versionManagement.isFactoryManaged();
        if(!factoryManaged) {
            uint256 version = versionManagement.getVersion();
            _setImplementation(ITokenLinkerFactory(factory).getImplementation(tokenLinkerType, version));
        }
        _setVersionManagement(versionManagement);
    }

    function init(
        address owner,
        bytes calldata params
    ) external {
        if (factoryManaged) {
            if(owner != factory) revert WrongInitialize();
        } else {
            if(owner == address(0)) revert ZeroAddress();
        }
        _setOwner(owner);
        _init(params);
    }
}

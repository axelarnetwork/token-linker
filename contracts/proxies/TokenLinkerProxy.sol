// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { Proxy } from './Proxy.sol';
import { Ownable } from './Ownable.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';

contract TokenLinkerProxy is Proxy {
    error WrongInitialize();

    address public immutable factory;
    ITokenLinkerFactory.TokenLinkerType public immutable tokenLinkerType;
    bool public immutable latest;

    // bytes32(uint256(keccak256('token-linker')) - 1)
    bytes32 public constant override contractId = 0x6ec6af55bf1e5f27006bfa01248d73e8894ba06f23f8002b047607ff2b1944ba;

    function implementation() public view override returns (address implementation_) {
        // solhint-disable-next-line no-inline-assembly
        if(latest) {
            implementation_ = ITokenLinkerFactory(factory).getLatestImplementation(tokenLinkerType);
        } else {
            assembly {
                implementation_ := sload(_IMPLEMENTATION_SLOT)
            }
        }
    }

    constructor() {
        factory = msg.sender;
        (latest, tokenLinkerType) = ITokenLinkerFactory(factory).getDeployingTokenLinkerData();
        if(!latest) {
            _setImplementation(ITokenLinkerFactory(factory).getLatestImplementation(tokenLinkerType));
        } else {
            _setImplementation(address(1));
        }
    }

    function init(
        address owner,
        bytes calldata params
    ) external {
        if (latest) {
            if(owner != address(0)) revert WrongInitialize();
        } else {
            if(owner == address(0)) revert ZeroAddress();
            _setOwner(owner);
        }
        _init(params);
    }
}

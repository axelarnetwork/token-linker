// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/StringAddressUtils.sol';
import { Proxied } from '../proxies/Proxied.sol';
import { FactoryUpgradable } from '../proxies/FactoryUpgradable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';
import { ITokenLinker } from '../interfaces/ITokenLinker.sol';
import { IFactoryUpgradable } from '../interfaces/IFactoryUpgradable.sol';
import { ITokenLinkerCallable } from '../interfaces/ITokenLinkerCallable.sol';
import { ITokenLinkerFactory } from '../interfaces/ITokenLinkerFactory.sol';

abstract contract TokenLinker is ITokenLinker, AxelarExecutable, Proxied, FactoryUpgradable {
    using StringToAddress for string;
    using AddressToString for address;

    IAxelarGasService public immutable gasService;
    // bytes32(uint256(keccak256('token-linker')) - 1)
    bytes32 public constant override contractId = 0x6ec6af55bf1e5f27006bfa01248d73e8894ba06f23f8002b047607ff2b1944ba;
    string public thisAddress;

    uint256 public constant VERSION = 0;

    constructor(address gatewayAddress_, address gasServiceAddress_) AxelarExecutable(gatewayAddress_) {
        if(gatewayAddress_ == address(0) || gasServiceAddress_ == address(0)) revert TokenLinkerZeroAddress();
        gasService = IAxelarGasService(gasServiceAddress_);
    }

    function token() public view virtual override returns (address);

    function implementationVersion() public pure override returns (uint256) {
        return VERSION;
    }

    function _setup(bytes calldata) internal virtual override {
        thisAddress = address(this).toString();
    }

    function sendToken(
        string calldata destinationChain,
        address to,
        uint256 amount
    ) external payable override notFrozen {
        emit Sending(destinationChain, to, amount);
        bytes memory payload = abi.encode(to, amount);
        _sendPayload(destinationChain, amount, payload);
    }

    function sendTokenWithData(
        string calldata destinationChain,
        address to,
        uint256 amount,
        bytes calldata data
    ) external payable override notFrozen {
        emit SendingWithData(destinationChain, to, amount, msg.sender, data);
        bytes memory payload = abi.encode(to, amount, msg.sender, data);
        _sendPayload(destinationChain, amount, payload);
    }

    function _sendPayload(
        string calldata destinationChain,
        uint256 amount,
        bytes memory payload
    ) internal {
        _takeToken(msg.sender, amount);
        string memory thisAddress_ = thisAddress;
        uint256 gasValue = _lockNative() ? msg.value - amount : msg.value;
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{ value: gasValue }(address(this), destinationChain, thisAddress_, payload, msg.sender);
        }
        gateway.callContract(destinationChain, thisAddress_, payload);
    }

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override notFrozen {
        if (sourceAddress.toAddress() != address(this)) return;
        (address recipient, uint256 amount) = abi.decode(payload, (address, uint256));
        _giveToken(recipient, amount);
        if (payload.length > 64) {
            (, , address from, bytes memory data) = abi.decode(payload, (address, uint256, address, bytes));
            ITokenLinkerCallable(recipient).processToken(token(), sourceChain, from, amount, data);
            emit ReceivingWithData(sourceChain, recipient, amount, from, data);
        } else {
            emit Receiving(sourceChain, recipient, amount);
        }
    }

    function _lockNative() internal pure virtual returns (bool) {
        return false;
    }

    function _giveToken(address to, uint256 amount) internal virtual;

    function _takeToken(address from, uint256 amount) internal virtual;
}

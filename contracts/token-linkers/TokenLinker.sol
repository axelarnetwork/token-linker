// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-utils-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-utils-solidity/contracts/StringAddressUtils.sol';
import { Proxied } from '../proxies/Proxied.sol';
import { IAxelarGateway } from '@axelar-network/axelar-utils-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';
import { ITokenLinker } from '../interfaces/ITokenLinker.sol';

abstract contract TokenLinker is ITokenLinker, AxelarExecutable, Proxied {
    using StringToAddress for string;
    using AddressToString for address;

    IAxelarGasService public immutable gasService;
    address public immutable gatewayAddress;
    // bytes32(uint256(keccak256('token-linker')) - 1)
    bytes32 public constant override contractId = 0x6ec6af55bf1e5f27006bfa01248d73e8894ba06f23f8002b047607ff2b1944ba;

    constructor(address gatewayAddress_, address gasServiceAddress_) {
        gatewayAddress = gatewayAddress_;
        gasService = IAxelarGasService(gasServiceAddress_);
    }

    function gateway() public view override returns (IAxelarGateway) {
        return IAxelarGateway(gatewayAddress);
    }

    function sendToken(
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable override {
        _takeToken(msg.sender, amount);
        string memory thisAddress = address(this).toString();
        bytes memory payload = abi.encode(to, amount);
        uint256 gasValue = _lockNative() ? msg.value - amount : msg.value;
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{ value: gasValue }(address(this), destinationChain, thisAddress, payload, msg.sender);
        }
        gateway().callContract(destinationChain, address(this).toString(), payload);
    }

    function _execute(
        string calldata, /*sourceChain*/
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        if (sourceAddress.toAddress() != address(this)) return;
        (address recipient, uint256 amount) = abi.decode(payload, (address, uint256));
        _giveToken(recipient, amount);
    }

    function _lockNative() internal pure virtual returns (bool) {
        return false;
    }

    function _giveToken(address to, uint256 amount) internal virtual;

    function _takeToken(address from, uint256 amount) internal virtual;
}

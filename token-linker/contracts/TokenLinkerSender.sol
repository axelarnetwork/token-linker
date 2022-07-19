// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinker.sol';
import { AddressToString } from '@axelar-network/axelar-utils-solidity/contracts/StringAddressUtils.sol';
import { TokenLinkerLockUnlock } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerLockUnlock.sol';
import { TokenLinkerMintBurn } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerMintBurn.sol';
import { TokenLinkerNative } from '@axelar-network/axelar-utils-solidity/contracts/token-linking/TokenLinkerNative.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';

abstract contract TokenLinkerSender is TokenLinker {
    using AddressToString for address;
    IAxelarGasService public immutable gasService;

    constructor(address gasService_) {
        gasService = IAxelarGasService(gasService_);
    }

    function sendToken(
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable {
        _takeToken(msg.sender, amount);
        string memory thisAddress = address(this).toString();
        bytes memory payload = abi.encode(to, amount);
        uint256 gasValue = _lockNative() ? msg.value - amount : msg.value;
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{value: gasValue}(address(this), destinationChain, thisAddress, payload, msg.sender);
        }
        gateway().callContract(destinationChain, address(this).toString(), payload);
    }

    function _lockNative() internal pure virtual returns (bool) {
        return false;
    }
}
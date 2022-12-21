// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IERC20 } from './interfaces/IERC20.sol';
import { IBurnableMintableCappedERC20 } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IBurnableMintableCappedERC20.sol';
import { IMintableCappedERC20 } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IMintableCappedERC20.sol';
import { BurnableMintableCappedERC20 } from '@axelar-network/axelar-cgp-solidity/contracts/BurnableMintableCappedERC20.sol';

import { ITokenLinker } from './interfaces/ITokenLinker.sol';
import { ITokenLinkerCallable } from './interfaces/ITokenLinkerCallable.sol';
import { IRemoteAddressValidator } from './interfaces/IRemoteAddressValidator.sol';

import { LinkedTokenData } from './libraries/LinkedTokenData.sol';

contract TokenLinker is ITokenLinker, AxelarExecutable {
    using LinkedTokenData for bytes32;

    IAxelarGasService public immutable gasService;
    IRemoteAddressValidator public immutable remoteAddressValidator;
    // bytes32(uint256(keccak256('remote-address-validator')) - 1)
    bytes32 public constant contractId = bytes32(0);
    mapping (bytes32 => bytes32) public tokenRegistry;
    bytes32 public immutable chainNameHash;
    enum RemoteActions {
        GIVE_TOKEN, GIVE_TOKEN_WITH_DATA, DEPLOY_TOKEN
    }

    constructor(
        address gatewayAddress_, 
        address gasServiceAddress_, 
        address remoteAddressValidatorAddress_, 
        string memory chainName
    ) AxelarExecutable(gatewayAddress_) {
        if(gatewayAddress_ == address(0) || gasServiceAddress_ == address(0)) revert TokenLinkerZeroAddress();
        gasService = IAxelarGasService(gasServiceAddress_);
        remoteAddressValidator = IRemoteAddressValidator(remoteAddressValidatorAddress_);
        chainNameHash = keccak256(bytes(chainName));
    }

    function getTokenAddress(bytes32 tokenId) public view override returns (address) {
        return tokenRegistry[tokenId].getAddress();
    }

    function getNativeTokenId(address tokenAddress) public view override returns (bytes32) {
        return keccak256(abi.encode(chainNameHash, tokenAddress));
    }

    function registerToken(address tokenAddress) external override returns (bytes32 tokenId) {
        tokenId = getNativeTokenId(tokenAddress);
        _validateNativeToken(tokenAddress);
        tokenRegistry[tokenId] = LinkedTokenData.createTokenData(tokenAddress, true);
    }

    function registerTokenAndDeployRemoteTokens(address tokenAddress, string[] calldata destinationChains) external payable override returns (bytes32 tokenId) {
        tokenId = getNativeTokenId(tokenAddress);
        tokenRegistry[tokenId] = LinkedTokenData.createTokenData(tokenAddress, true);
        uint256 length = destinationChains.length;
        (string memory name, string memory symbol, uint8 decimals) = _validateNativeToken(tokenAddress);
        for(uint256 i; i<length; ++i) {
            _deployRemoteToken(tokenId, name, symbol, decimals, destinationChains[i]);
        }
    }

    function deployRemoteTokens(bytes32 tokenId, string[] calldata destinationChains) external payable override {
        bytes32 tokenData = tokenRegistry[tokenId];
        if(!tokenData.isNative()) revert NotNativeToken();
        address tokenAddress = tokenData.getAddress();
        
        (string memory name, string memory symbol, uint8 decimals) = _validateNativeToken(tokenAddress);

        uint256 length = destinationChains.length;
        for(uint256 i; i<length; ++i) {
            _deployRemoteToken(tokenId, name, symbol, decimals, destinationChains[i]);
        }
    }

    function _deployRemoteToken(
        bytes32 tokenId, 
        string memory name, 
        string memory symbol, 
        uint8 decimals, 
        string calldata destinationChain
    ) internal {
        bytes memory payload = abi.encode(RemoteActions.DEPLOY_TOKEN, tokenId, name, symbol, decimals);
        _sendPayload(destinationChain, payload);
    }

    function _validateNativeToken(address tokenAddress) internal returns (string memory name, string memory symbol, uint8 decimals) {
        IERC20 token = IERC20(tokenAddress);
        name = token.name();
        symbol = token.symbol();
        decimals = token.decimals();
    }

    function _deployToken(
        bytes32 tokenId, 
        string memory tokenName, 
        string memory tokenSymbol, 
        uint8 decimals
    ) internal {
        address tokenAddress = address(new BurnableMintableCappedERC20(tokenName, tokenSymbol, decimals, 0));
        tokenRegistry[tokenId] = LinkedTokenData.createTokenData(tokenAddress, false);
    }

    function sendToken(
        bytes32 tokenId,
        string calldata destinationChain,
        address to,
        uint256 amount
    ) external payable override {
        _takeToken(tokenId, msg.sender, amount);
        emit Sending(destinationChain, to, amount);
        bytes memory payload = abi.encode(RemoteActions.GIVE_TOKEN, tokenId, to, amount);
        _sendPayload(destinationChain, payload);
    }

    function sendTokenWithData(
        bytes32 tokenId,
        string calldata destinationChain,
        address to,
        uint256 amount,
        bytes calldata data
    ) external payable override {
        _takeToken(tokenId, msg.sender, amount);
        emit SendingWithData(destinationChain, to, amount, msg.sender, data);
        bytes memory payload = abi.encode(RemoteActions.GIVE_TOKEN_WITH_DATA, tokenId, to, amount, msg.sender, data);
        _sendPayload(destinationChain, payload);
    }

    function _sendPayload(
        string calldata destinationChain,
        bytes memory payload
    ) internal {
        string memory destinationAddress = remoteAddressValidator.getRemoteAddress(destinationChain);
        uint256 gasValue = msg.value;
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{ value: gasValue }(address(this), destinationChain, destinationAddress, payload, msg.sender);
        }
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        if (!remoteAddressValidator.validateSender(sourceChain, sourceAddress)) return;
        RemoteActions action = abi.decode(payload, (RemoteActions));
        if(action == RemoteActions.DEPLOY_TOKEN) {
            bytes32 tokenId;
            string memory tokenName;
            string memory tokenSymbol;
            uint8 decimals;
            (, tokenId, tokenName, tokenSymbol, decimals) = abi.decode(payload, (RemoteActions, bytes32, string, string, uint8));
            _deployToken(tokenId, tokenName, tokenSymbol, decimals);
        } else if(action == RemoteActions.GIVE_TOKEN) {
            bytes32 tokenId;
            address to;
            uint256 amount;
            (, tokenId, to, amount) = abi.decode(payload, (RemoteActions, bytes32, address, uint256));
            _giveToken(tokenId, to, amount);
        } else if(action == RemoteActions.GIVE_TOKEN_WITH_DATA) {
            bytes32 tokenId;
            address to;
            uint256 amount;
            bytes memory data;
            (, tokenId, to, amount, data) = abi.decode(payload, (RemoteActions, bytes32, address, uint256, bytes));
            _giveTokenWithData(tokenId, to, amount, sourceChain, data);
        }
    }

    function _transfer(address tokenAddress, address to, uint256 amount) internal {
        (bool success, bytes memory returnData) = tokenAddress.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFailed();
    }

    function _transferFrom(address tokenAddress, address from, uint256 amount) internal {
        (bool success, bytes memory returnData) = tokenAddress.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFromFailed();
    }

    function _mint(address tokenAddress, address to, uint256 amount) internal {
        (bool success,) = tokenAddress.call(abi.encodeWithSelector(IMintableCappedERC20.mint.selector, to, amount));

        if (!success || tokenAddress.code.length == 0) revert MintFailed();
    }

    function _burn(address tokenAddress, address from, uint256 amount) internal {
        (bool success,) = tokenAddress.call(
            abi.encodeWithSelector(IBurnableMintableCappedERC20.burnFrom.selector, from, amount)
        );

        if (!success || tokenAddress.code.length == 0) revert BurnFailed();
    }

    function _giveToken(bytes32 tokenId, address to, uint256 amount) internal {
        bytes32 tokenData = tokenRegistry[tokenId];
        address tokenAddress = tokenData.getAddress();
        if(tokenData.isNative()) {
            _transfer(tokenAddress, to, amount);
        } else {
            _mint(tokenAddress, to, amount);
        }
    }
    function _takeToken(bytes32 tokenId, address to, uint256 amount) internal {
        bytes32 tokenData = tokenRegistry[tokenId];
        address tokenAddress = tokenData.getAddress();
        if(tokenData.isNative()) {
            _transferFrom(tokenAddress, to, amount);
        } else {
            _burn(tokenAddress, to, amount);
        }
    }
    function _giveTokenWithData(
        bytes32 tokenId, 
        address to,
        uint256 amount, 
        string calldata sourceChain,
        bytes memory data
    ) internal {
        bytes32 tokenData = tokenRegistry[tokenId];
        address tokenAddress = tokenData.getAddress();
        if(tokenData.isNative()) {
            _transfer(tokenAddress, to, amount);
        } else {
            _mint(tokenAddress, to, amount);
        }
        ITokenLinkerCallable(to).processToken(tokenAddress, sourceChain, amount, data);
    }
}

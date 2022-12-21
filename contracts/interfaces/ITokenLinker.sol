// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface ITokenLinker {
    error TokenLinkerZeroAddress();
    error TransferFailed();
    error TransferFromFailed();
    error MintFailed();
    error BurnFailed();
    error NotNativeToken();

    event Sending(string destinationChain, address indexed destinationAddress, uint256 indexed amount);
    event SendingWithData(
        string destinationChain,
        address indexed destinationAddress,
        uint256 indexed amount,
        address indexed from,
        bytes data
    );
    event Receiving(string sourceChain, address indexed destinationAddress, uint256 indexed amount);
    event ReceivingWithData(
        string sourceChain,
        address indexed destinationAddress,
        uint256 indexed amount,
        address indexed from,
        bytes data
    );
    function getTokenAddress(bytes32 tokenId) external view returns (address tokenAddress);

    function getNativeTokenId(address tokenAddress) external view returns (bytes32 tokenId);

    function registerToken(address tokenAddress) external returns (bytes32 tokenId);

    function registerTokenAndDeployRemoteTokens(
        address tokenAddress, 
        string[] calldata destinationChains
    ) external payable returns (bytes32 tokenId);

    function deployRemoteTokens(bytes32 tokenId, string[] calldata destinationChains) external payable;

    function sendToken(
        bytes32 tokenId,
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable;

    function sendTokenWithData(
        bytes32 tokenId,
        string memory destinationChain,
        address to,
        uint256 amount,
        bytes calldata data
    ) external payable;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface ITokenLinkerFactory {
    error AlreadyInitialized();
    error ArrayLengthMismatch();
    error InsufficientAmountForGas();
    error WrongSourceCaller();
    error WrongTokenLinkerType();
    error ImplementationIsNotContract();
    error LengthMismatch();
    error InvalidVersion();

    event TokenLinkerDeployed(TokenLinkerType tlt, bytes32 indexed id, bytes params, bool factoryManaged, address indexed at);

    enum TokenLinkerType {
        lockUnlock, mintBurn, mintBurnExternal, native
    }

    function proxyCodehash() external view returns (bytes32);

    function getTokenLinkerId(address creator, bytes32 salt) external pure returns (bytes32 id);

    function tokenLinkerIds(uint256 index) external view returns (bytes32 id);

    function tokenLinkerTypes(bytes32 id) external view returns (TokenLinkerType tlt);

    function deploy(
        TokenLinkerType tlt,
        bytes32 salt,
        bytes calldata params,
        bool factoryManaged
    ) external;

    function tokenLinker(bytes32 id) external view returns (address tokenLinkerAddress);

    function numberDeployed() external view returns (uint256);

    function getLatestImplementation(TokenLinkerType tlt) external view returns (address);

    function getImplementation(TokenLinkerType tlt, uint256 version) external view returns (address);

    function getDeployingTokenLinkerData() external returns (bool latest, TokenLinkerType tlt);
}

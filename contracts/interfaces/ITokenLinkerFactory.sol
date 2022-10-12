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

    event TokenLinkerDeployed(uint256 tlt, bytes32 indexed id, bytes params, bool factoryManaged, address indexed at);

    function factoryManagedImplementations(uint256 index) external view returns (address implementaionAddress);

    function upgradableImplementations(uint256 index) external view returns (address implementaionAddress);

    function factoryManagedProxyCodehash() external view returns (bytes32);

    function upgradableProxyCodehash() external view returns (bytes32);

    function getTokenLinkerId(address creator, bytes32 salt) external pure returns (bytes32 id);

    function tokenLinkerIds(uint256 index) external view returns (bytes32 id);

    function tokenLinkerType(bytes32 id) external view returns (uint256 tlt);

    function deploy(
        uint256 tlt,
        bytes32 salt,
        bytes calldata params,
        bool factoryManaged
    ) external;

    function tokenLinker(bytes32 id, bool factoryManaged) external view returns (address tokenLinkerAddress);

    function numberDeployed() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface ITokenLinkerFactory {

    error AlreadyInitialized();
    error ArrayLengthMismatch();
    error InsufficinetAmountForGas();
    error WrongSourceCaller();
    error WrongTokenLinkerType();
    error ZeroAddress();
    error ImplementationIsNotContract();

    event TokenLinkerDeployed(uint256 tlt, bytes32 indexed id, bytes params, bool factoryManaged, address indexed at);

    function implementations(uint256 index) external view returns (address implementaionAddress);

    function proxyCodehash() external view returns (bytes32);

    function getTokenLinkerId(address creator, bytes32 salt) external pure returns(bytes32 id);

    function tokenLinkerIds(uint256 index) external view returns(bytes32 id);

    function tokenLinkerType(bytes32 id) external view returns(uint256 tlt);

    function deploy(uint256 tlt, bytes32 salt, bytes calldata params, bool factoryManaged) external;

    function tokenLinker(bytes32 id) external view returns (address deployedAddress_);

     function numberDeployed() external view returns (uint256);
}
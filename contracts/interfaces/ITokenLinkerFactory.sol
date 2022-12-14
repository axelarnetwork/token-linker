// SPDX-License-Identifier: MIT

import { IFreezable } from './IFreezable.sol';
import { IUpgradable } from './IUpgradable.sol';
import { IAxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol';
pragma solidity 0.8.9;

interface ITokenLinkerFactory is IFreezable, IAxelarExecutable, IUpgradable{
    error AlreadyInitialized();
    error ArrayLengthMismatch();
    error InsufficientAmountForGas();
    error WrongSourceCaller();
    error WrongTokenLinkerType();
    error ImplementationIsNotContract();
    error LengthMismatch();
    error InvalidVersion();

    event TokenLinkerDeployed(TokenLinkerType indexed tlt, bytes32 versionManagment, bytes32 indexed id, bytes params, address indexed at);

    enum TokenLinkerType {
        lockUnlock, mintBurn, mintBurnExternal, native
    }

    function proxyCodehash() external view returns (bytes32);

    function latestVersion() external view returns (uint256);

    function getTokenLinkerId(address creator, bytes32 salt) external pure returns (bytes32 id);

    function tokenLinkerIds(uint256 index) external view returns (bytes32 id);

    function tokenLinkerTypes(bytes32 id) external view returns (TokenLinkerType tlt);

    function deploy(
        TokenLinkerType tlt,
        bytes32 versionManagement,
        bytes32 salt,
        bytes calldata params
    ) external;

    function tokenLinker(bytes32 id) external view returns (address tokenLinkerAddress);

    function numberDeployed() external view returns (uint256);

    function getLatestImplementation(TokenLinkerType tlt) external view returns (address);

    function getImplementation(TokenLinkerType tlt, uint256 version) external view returns (address);

    function deployingData() external view returns(bytes memory);
}


// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IVersionManaged {
    function getVersionManagement() external view returns(bytes32 vm);
        
    function getCurrentVersion() external view returns(uint256 currentVersion);
}


// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IExternalTokenReference {
   function tokenAddress() external view returns(address);
}
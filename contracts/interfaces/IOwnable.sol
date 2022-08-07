// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IOwnable {
    error NotOwner();
    error ZeroAddress();

    event OwnershipTransferred(address newOwner);

    function owner() external view returns (address owner_);

    function transferOwnership(address newOwner) external;
}

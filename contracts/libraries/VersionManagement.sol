// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library VersionManagement {
    // 0xff << (31 * 8)
    uint256 public constant FACTORY_MANAGED_MASK = 0xff00000000000000000000000000000000000000000000000000000000000000;

    function isFactoryManaged(bytes32 vm) internal pure returns (bool){
        return (uint256(vm) & FACTORY_MANAGED_MASK) == FACTORY_MANAGED_MASK;
    }

    function getVersion(bytes32 vm) internal pure returns (uint256) {
        return uint256(vm) & ~FACTORY_MANAGED_MASK;
    }

    function getVersionManagement(bool factoryManaged, uint256 version) internal pure returns (bytes32 vm) {
        vm = bytes32(version);
        if(factoryManaged) vm |= bytes32(FACTORY_MANAGED_MASK);
    }
}
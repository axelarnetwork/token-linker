// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;    

library LinkedTokenData {
    bytes32 public constant IS_NATIVE_MASK = bytes32(uint256(0xff<<248));
    function getAddress(bytes32 tokenData) internal pure returns (address) {
        return address(uint160(uint256((tokenData))));
    }
    function isNative(bytes32 tokenData) internal pure returns (bool) {
        return tokenData & IS_NATIVE_MASK == IS_NATIVE_MASK;
    }

    function createTokenData(address tokenAddress, bool native) internal pure returns (bytes32 tokenData) {
        tokenData = bytes32(uint256(uint160(tokenAddress)));
        if(native) tokenData |= IS_NATIVE_MASK;
    }
}
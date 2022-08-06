// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { FactoryImplementationLookup } from './FactoryImplementationLookup.sol';
import { IProxied } from '../interfaces/IProxied.sol';

abstract contract Proxied is IProxied {
    uint256[20] private storageGap;
    // bytes32(uint256(keccak256('not-a-proxy')) - 1)
    bytes32 internal constant _NOT_A_PROXY = 0x924ca5ddb2da563d46ccd770cab67674730c082261612268d27d3912d588ca1c;

    constructor() {
        assembly {
            sstore(_NOT_A_PROXY, true)
        }
    }

    function setup(bytes calldata data) external override {
        bool notProxy;
        assembly {
            notProxy := sload(_NOT_A_PROXY)
        }
        if (notProxy) revert NotProxy();

        _setup(data);
    }

    // solhint-disable-next-line no-empty-blocks
    function _setup(bytes calldata data) internal virtual {}
}

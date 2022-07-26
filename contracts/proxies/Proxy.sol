// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IProxy } from '../interfaces/IProxy.sol';
import { ImplementationLookup } from './ImplementationLookup.sol';
import { IProxied } from '../interfaces/IProxied.sol';

abstract contract Proxy is IProxy, ImplementationLookup {
    // solhint-disable-next-line no-empty-blocks
    function setup(bytes calldata data) public {}

    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        address implementaion_ = implementation();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementaion_, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _init(bytes calldata params) internal {
        address implementationAddress = implementation();
        if (IProxied(implementationAddress).contractId() != IProxy(this).contractId()) revert InvalidImplementation();

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = implementationAddress.delegatecall(
            //0x9ded06df is the setup selector.
            abi.encodeWithSelector(0x9ded06df, params)
        );
        if (!success) revert SetupFailed();
    }

    receive() external payable virtual {
        revert EtherNotAccepted();
    }
}

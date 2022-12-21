// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;    

contract Deployer {
    event Deployed(address indexed addr);
    function init(bytes memory bytecode) external {
        if (bytecode.length == 0) revert('EMPTY_BYTECODE');
        address deployedAddress;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            deployedAddress := create(0, add(bytecode, 32), mload(bytecode))
        }

        if (deployedAddress == address(0)) revert('FAILED_DEPLOY');
        emit Deployed(deployedAddress);
        selfdestruct;
    }
}
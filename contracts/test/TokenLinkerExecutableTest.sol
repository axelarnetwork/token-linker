// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { ITokenLinkerCallable } from '../interfaces/ITokenLinkerCallable.sol';
import { IERC20 } from '../interfaces/IERC20.sol';

contract TokenLinkerExecutableTest is ITokenLinkerCallable {
    string public val;

    function processToken(
        address tokenAddress,
        string calldata,
        address,
        uint256 amount,
        bytes calldata data
    ) external override {
        address to;
        (to, val) = abi.decode(data, (address, string));
        if (tokenAddress == address(0)) {
            to.call{ value: amount }('');
        } else {
            IERC20(tokenAddress).transfer(to, amount);
        }
    }

    receive() external payable {}
}

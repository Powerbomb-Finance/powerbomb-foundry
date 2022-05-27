// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IBridge {
    function deposit(address to, uint chainId, address token, uint amount) external;
}
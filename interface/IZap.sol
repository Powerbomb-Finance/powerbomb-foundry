// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IZap {
    function add_liquidity(address, uint[4] memory, uint) external returns (uint);
}

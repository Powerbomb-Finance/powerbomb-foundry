// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPool {
    function totalSupply() external view returns (uint);

    function getRate() external view returns (uint);
}
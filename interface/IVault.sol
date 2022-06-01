// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface IVault {
    function token0() external view returns (address);
    
    function token1() external view returns (address);
}
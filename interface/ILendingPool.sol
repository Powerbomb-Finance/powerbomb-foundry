// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILendingPool {
    function supply(address asset, uint amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint amount, address to) external;
    function getReserveData(address asset) external view returns (
        uint, uint128, uint128, uint128, uint128, uint128, uint40, uint16, address
    );
}
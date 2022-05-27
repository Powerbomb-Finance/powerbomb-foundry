// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPbFarm {
    function isFarm() external view returns (bool);

    function deposit(address token, uint amount) external;

    function withdraw(address token, uint amount) external;
}
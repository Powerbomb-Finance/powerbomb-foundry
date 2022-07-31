// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IPool {
    function deposit(uint _pid, uint _amount, bool _stake) external;
    function withdraw(uint _pid, uint _amount) external;
}
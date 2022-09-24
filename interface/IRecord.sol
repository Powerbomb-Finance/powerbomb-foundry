// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IFarm {
    function update(bool, address, uint, uint) external;
}
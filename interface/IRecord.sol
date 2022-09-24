// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IRecord {
    function updateUser(bool, address, uint, uint) external;

    function userInfo(address) external view returns (uint, uint, uint, uint);
}
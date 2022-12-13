// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for peng together record contract
interface IRecord {
    function updateUser(bool deposit, address account, uint amount, uint lpTokenAmt) external;

    function userInfo(address account) external view returns (
        uint depositBal,
        uint lpTokenBal,
        uint ticketBal,
        uint lastUpdateTimestamp
    );
}
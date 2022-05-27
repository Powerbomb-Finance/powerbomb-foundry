// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPbState {
    function recordDeposit(address account, uint amount, address rewardToken) external;

    function recordWithdraw(address account, uint amount) external;

    function recordClaim(address account) external;
}
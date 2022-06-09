// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface IReward {
    function recordDeposit(address account, uint amount) external;

    function recordWithdraw(address account, uint amount) external;

    function harvest(uint amount) external;

    function claim(address account) external;

    function userInfo(address account) external view returns (uint balance, uint rewardStartAt);

    function accRewardPerlpToken() external view returns (uint);

    function getAllPool() external view returns (uint);
}
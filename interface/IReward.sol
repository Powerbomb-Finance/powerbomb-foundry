// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface IReward {
    function recordDeposit(address account, uint amount, address rewardToken) external;

    function recordWithdraw(address account, uint amount, address rewardToken) external;

    function harvest(uint amount0, uint amount1) external;

    function claim(address account) external;

    function userInfo(address rewardToken, address account) external view returns (uint balance);

    function getAllPool() external view returns (uint);
}
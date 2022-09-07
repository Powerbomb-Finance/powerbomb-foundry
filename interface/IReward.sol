// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IReward {
    function recordDeposit(address account, uint amount, address rewardToken) external;

    function recordWithdraw(address account, uint amount, address rewardToken) external;

    function harvest(uint amount0, uint amount1) external;

    function claim(address account) external;

    function userInfo(address account, address rewardToken) external view returns (uint balance, uint rewardStartAt);

    function rewardInfo(address rewardToken) external view returns (uint accRewardPerlpToken, uint basePool, address ibRewardToken, uint lastIbRewardTokenAmt);

    function getAllPool() external view returns (uint);
}
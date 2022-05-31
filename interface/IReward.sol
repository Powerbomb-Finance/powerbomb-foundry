// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IReward {
    function recordDeposit(address account, uint amount, address rewardToken) external;

    function recordWithdraw(address account, uint amount, address rewardToken) external;

    function harvest(address token0, address token1, uint amount0, uint amount1) external;

    function claim(address account) external;

    function userInfo(address rewardToken, address account) external view returns (uint balance);

    // function rewardInfo(address rewardToken) external view returns (uint accRewardPerlpToken, uint basePool, address ibRewardToken, uint lastIbRewardTokenAmt);

    function getAllPool() external view returns (uint);
}
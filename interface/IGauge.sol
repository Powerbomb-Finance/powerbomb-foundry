// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGauge {
    function deposit(uint amount) external;

    function withdraw(uint amount) external;

    function claim_rewards() external;

    function claimable_reward_write(address addr, address token) external returns (uint);

    function claimable_reward(address user_, address rewardToken) external view returns (uint);

    function claimed_reward(address addr, address token) external view returns (uint);
    
    function balanceOf(address account) external view returns (uint);

    function claimable_tokens(address addr) external returns (uint);
}
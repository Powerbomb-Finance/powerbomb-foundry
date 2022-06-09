// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface IGauge {
    function deposit(uint amount) external;

    function withdraw(uint amount) external;

    function claim_rewards() external;

    function claimable_reward_write(address _addr, address _token) external returns (uint);

    function balanceOf(address account) external view returns (uint);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IIncentivesController {
    function getRewardsBalance(address[] calldata assets, address user) external view returns (uint);

    function claimRewards(address[] calldata assets, uint amount, address to) external returns (uint);
}

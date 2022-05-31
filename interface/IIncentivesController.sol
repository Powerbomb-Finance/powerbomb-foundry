// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IIncentivesController {
    function getAllUserRewards(address[] calldata assets, address user) external view returns(address[] memory, uint[] memory);
    function claimAllRewardsToSelf(address[] calldata assets) external returns (address[] memory, uint[] memory);
}
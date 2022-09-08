// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IRewardsController {
    function getRewardsByAsset(address asset) external view returns (address[] memory);

    function claimRewards(
        address[] memory assets,
        uint amount,
        address to,
        address reward
    ) external returns (uint);
}

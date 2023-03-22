// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IChainLink {
    function latestRoundData() external view returns (uint80, int, uint, uint, uint80);
}
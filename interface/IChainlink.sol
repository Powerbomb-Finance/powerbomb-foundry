// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for get oracle price from chainlink
interface IChainlink {
    function latestRoundData() external view returns (
        uint80 roundId,
        int answer,
        uint startedAt,
        uint updatedAt,
        uint80 answeredInRound
    );
}
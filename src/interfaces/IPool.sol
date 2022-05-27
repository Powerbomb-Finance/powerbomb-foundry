// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPool {
    function addLiquidity(uint[] memory amounts, uint minToMint, uint deadline) external;

    function removeLiquidityOneToken(uint tokenAmount, uint tokenIndex, uint minAmount, uint deadline) external;
}
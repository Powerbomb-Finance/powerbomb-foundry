// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for curve zap contract
interface IZap {
    function add_liquidity(
        address pool,
        uint[4] memory depositAmounts,
        uint minMintAmount
    ) external returns (uint);

    function remove_liquidity_one_coin(
        address pool,
        uint burnAmount,
        int128 i,
        uint minAmount
    ) external returns (uint);

    function calc_withdraw_one_coin(
        address pool,
        uint tokenAmount,
        int128 i
    ) external view returns (uint);

    function calc_token_amount(
        address pool,
        uint[4] memory amounts,
        bool isDeposit
    ) external view returns (uint);
}
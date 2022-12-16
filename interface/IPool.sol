// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for curve pool
interface IPool {
    function get_virtual_price() external view returns (uint);

    function add_liquidity(
        uint[2] memory amounts,
        uint minMintAmount
    ) external payable returns (uint);

    function remove_liquidity_one_coin(
        uint burnAmount,
        int128 i,
        uint minReceived
    ) external returns (uint);

    function calc_token_amount(
        uint[2] memory amounts,
        bool isDeposit
    ) external payable returns (uint);

    function calc_withdraw_one_coin(
        uint burnAmount,
        int128 i
    ) external returns (uint);
}
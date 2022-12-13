// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for curve pool
interface IPool {
    function get_virtual_price() external view returns (uint);

    function add_liquidity(
        uint[2] memory amounts,
        uint _min_mint_amount
    ) external payable returns (uint);

    function remove_liquidity_one_coin(
        uint _burn_amount,
        int128 i,
        uint _min_received
    ) external returns (uint);

    function calc_token_amount(
        uint[2] memory _amounts,
        bool _is_deposit
    ) external payable returns (uint);

    function calc_withdraw_one_coin(
        uint _burn_amount,
        int128 i
    ) external returns (uint);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IZap {
    function add_liquidity(address _pool, uint[4] memory _deposit_amounts, uint _min_mint_amount) external returns (uint);

    function remove_liquidity_one_coin(address _pool, uint _burn_amount, int128 i, uint _min_amount) external returns (uint);
}

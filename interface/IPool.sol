// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPool {
    function get_virtual_price() external view returns (uint);
}

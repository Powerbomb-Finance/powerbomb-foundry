// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for curve crv minter
interface IMinter {
    function mint(address gauge) external;
}
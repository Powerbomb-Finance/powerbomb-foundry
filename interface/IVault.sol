// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for peng together vault contract
interface IVault  {
    function depositByHelper(
        address token,
        uint amount,
        uint amountOutMin,
        address account
    ) external payable;

    function withdrawByHelper(
        address token,
        uint amount,
        uint amountOutMin,
        address account
    ) external returns (uint actualAmt);
}
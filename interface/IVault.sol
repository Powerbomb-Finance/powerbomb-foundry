// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
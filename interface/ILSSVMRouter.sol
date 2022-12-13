// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for sudoswap router
interface ILSSVMRouter {
    struct PairSwapAny {
        address pair;
        uint256 numItems;
    }

    function swapETHForAnyNFTs(
        PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    ) external payable returns (uint256 remainingValue);
}
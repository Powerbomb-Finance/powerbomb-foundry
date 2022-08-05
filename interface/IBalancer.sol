// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IBalancer {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint limit,
        uint deadline
    ) external returns (uint amountCalculated);

    enum JoinKind { 
        INIT, 
        EXACT_TOKENS_IN_FOR_BPT_OUT, 
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }

    struct JoinPoolRequest {
        address[] assets;
        uint[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external;

    struct BatchSwapStep {
        bytes32 poolId;
        uint assetInIndex;
        uint assetOutIndex;
        uint amount;
        bytes userData;
    }

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds,
        int[] memory limits,
        uint deadline
    ) external returns (int[] memory assetDeltas);
}

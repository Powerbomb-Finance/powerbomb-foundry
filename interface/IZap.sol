// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IZap {
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

    function depositSingle(
        address _rewardPoolAddress,
        address _inputToken,
        uint256 _inputAmount,
        bytes32 _balancerPoolId,
        JoinPoolRequest memory _request
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IAuraZap {
    struct JoinPoolRequest {
        address[] assets;
        uint[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function depositSingle(
        address _rewardPoolAddress,
        address _inputToken,
        uint _inputAmount,
        bytes32 _balancerPoolId,
        JoinPoolRequest memory _request
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IBalancer.sol";

interface IBalancerHelper {
    function queryJoin(
        bytes32 poolId, 
        address sender, 
        address recipient, 
        IBalancer.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn);

    function queryExit(
        bytes32 poolId, 
        address sender, 
        address recipient, 
        IBalancer.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut);
}
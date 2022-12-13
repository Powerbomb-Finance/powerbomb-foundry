// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

/// @title interface for stargate router - bridge in native eth
interface IStargateRouterETH {
    function swapETH(
        uint16 _dstChainId,
        address _refundAddress,
        bytes memory _toAddress,
        uint _amountLD,
        uint _minAmountLD
    ) external payable;
}

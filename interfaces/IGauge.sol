// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface IGauge {
    function getReward(address account, address[] memory tokens) external;

    function balanceOf(address account) external view returns (uint);

    function stake() external view returns (address);

    function deposit(uint amount, uint tokenId) external;

    function withdraw(uint amount) external;

    function earned(address token, address account) external view returns (uint);
}
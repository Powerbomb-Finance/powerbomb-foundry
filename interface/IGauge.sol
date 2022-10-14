// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGauge {
    function getReward() external;

    function balanceOf(address) external view returns (uint);

    function withdraw(uint amount, bool claim) external;
}

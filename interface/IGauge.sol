// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGauge {
    function getReward() external;

    function getReward(address account, bool claimExtras) external;

    function balanceOf(address) external view returns (uint);

    function withdraw(uint amount, bool claim) external;

    function withdrawAndUnwrap(uint amount, bool claim) external;

    function earned(address account) external view returns (uint);

    function extraRewards(uint index) external view returns (address);

    function rewards(address account) external view returns (uint);
}

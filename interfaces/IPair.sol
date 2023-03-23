// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IPair is IERC20Upgradeable {
    function tokens() external view returns (address, address);

    function stable() external view returns (bool);

    function getReserves() external view returns (uint _reserve0, uint _reserve1);
}
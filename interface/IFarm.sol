// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IFarm {
    function deposit(uint amount, uint slippage) external returns (uint);
    
    function withdraw(uint amount, uint slippage) external returns (uint);

    function reward() external view returns (address);

    function getAllPoolInUSD() external view returns (uint);

    function getPricePerFullShareInUSD() external view returns (uint);
}
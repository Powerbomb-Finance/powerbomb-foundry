// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../interface/IPool.sol";

contract ContractTest is Test {
    IERC20 lpToken = IERC20(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
    IPool pool = IPool(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    function setUp() public {}

    function testExample() public {
        uint amount = 100_000 ether;
        deal(address(lpToken), address(this), amount);
        lpToken.approve(address(pool), amount);
        pool.deposit(32, amount, true);
    }
}

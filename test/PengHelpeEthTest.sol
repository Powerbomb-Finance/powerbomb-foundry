// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/PengHelperEth.sol";
import "../src/PbProxy.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PengHelperEthTest is Test {
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address pengHelperOp = address(this);
    PengHelperEth helper;

    function setUp() public {
        PbProxy proxy;
        helper = new PengHelperEth();
        proxy = new PbProxy(
            address(helper),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address)")),
                pengHelperOp
            )
        );
        helper = PengHelperEth(payable(address(proxy)));
    }

    function test() public {
        // deposit eth
        helper.deposit{value: 1.1 ether}(weth, 1 ether, 0.99 ether);

        // deposit usdc
        deal(address(usdc), address(this), 100e6);
        usdc.approve(address(helper), 100e6);
        helper.deposit{value: 0.1 ether}(usdc, 100e6, 99e6);

        // withdraw eth
        helper.withdraw{value: 0.2 ether}(weth, 1 ether, 0, 0.1 ether);

        // withdraw usdc
        helper.withdraw{value: 0.2 ether}(usdc, 100e6, 0, 0.1 ether);
    }

    receive() external payable {}
}
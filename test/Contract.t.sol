// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../interface/IPool.sol";
import "../interface/IGauge.sol";
import "../interface/IZap.sol";
import "../interface/ISwapRouter.sol";

import "../src/Contract.sol";

contract ContractTest is Test {
    IERC20 lpToken = IERC20(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
    IPool pool = IPool(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    IGauge gauge = IGauge(0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e);
    IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 cvx = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IZap zap = IZap(0xA79828DF1850E8a3A3064576f380D90aECDD3359);
    uint pid;

    function setUp() public {
        // pid = 32;

        // crv.approve(address(swapRouter), type(uint).max);
        // cvx.approve(address(swapRouter), type(uint).max);
        // usdc.approve(address(zap), type(uint).max);
        // lpToken.approve(address(pool), type(uint).max);
    }

    function testExample() public {
        uint amount = 100_000 ether;
        // deal(address(lpToken), address(this), amount);
        // pool.deposit(pid, amount, true);

        // skip(864000);
        // harvest();

        Contract vault = new Contract();
        deal(address(lpToken), address(vault), amount);
        vault.deposit();
        skip(864000);
        vm.roll(block.number + 1);
        vault.harvest();
    }

    // function harvest() public {
    //     gauge.getReward();

    //     // console.log(crv.balanceOf(address(this)));
    //     // console.log(cvx.balanceOf(address(this)));

    //     ISwapRouter.ExactInputParams memory params = 
    //         ISwapRouter.ExactInputParams({
    //             path: abi.encodePacked(address(crv), uint24(10000), address(weth), uint24(500), address(usdc)),
    //             recipient: address(this),
    //             deadline: block.timestamp,
    //             amountIn: crv.balanceOf(address(this)),
    //             amountOutMinimum: 0
    //         });
    //     uint usdcAmt = swapRouter.exactInput(params);

    //     params = 
    //         ISwapRouter.ExactInputParams({
    //             path: abi.encodePacked(address(cvx), uint24(10000), address(weth), uint24(500), address(usdc)),
    //             recipient: address(this),
    //             deadline: block.timestamp,
    //             amountIn: cvx.balanceOf(address(this)),
    //             amountOutMinimum: 0
    //         });
    //     usdcAmt += swapRouter.exactInput(params);
    //     // console.log(usdc.balanceOf(address(this)));

    //     uint[4] memory amounts = [0, 0, usdcAmt, 0];
    //     uint lpTokenAmt = zap.add_liquidity(address(lpToken), amounts, 0);
    //     pool.deposit(pid, lpTokenAmt, true);
    // }
}

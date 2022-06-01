// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/PbUniV3.sol";
import "../src/PbUniV3Reward.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IUniswapV3PoolState.sol";
import "../interface/IQuoter.sol";
import "../interface/IReward.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/TickMath.sol";
import "../libraries/LiquidityAmounts.sol";

contract PbUniV3Test is Test {
    PbUniV3 vault;
    PbUniV3Reward reward;
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3PoolState uniswapV3PoolState = IUniswapV3PoolState(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IQuoter quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function setUp() public {
        vault = new PbUniV3();
        vault.initialize(WETH, USDC, 500, address(this));
        reward = new PbUniV3Reward();
        reward.initialize(address(vault), 500, address(1));
        vault.setReward(IReward(address(reward)));
    }

    function testDeposit() public {
        deal(address(USDC), address(this), 9000e6);
        // Assume get ticks from API
        uint160 sqrtPriceX96Lower = 2991631685175907615962449;
        uint160 sqrtPriceX96Upper = 3663985563520335739962051;
        int24[] memory ticks = vault.getTicks(sqrtPriceX96Lower, sqrtPriceX96Upper);
        ticks[0] = ticks[0] / 10 * 10;
        ticks[1] = ticks[1] / 10 * 10;
        // Approve
        USDC.approve(address(vault), type(uint).max);
        // First deposit with WBTC reward
        uint amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(WETH), 500, 5000e6 / 2, 0);
        vault.deposit(5000e6, amountOutMin, 2000, ticks[0], ticks[1], address(WBTC));
        // Bot reinvest
        // console.log(WETH.balanceOf(address(vault)));
        // console.log(USDC.balanceOf(address(vault)));
        amountOutMin = quoter.quoteExactInputSingle(address(WETH), address(USDC), 500, WETH.balanceOf(address(vault)) / 2, 0);
        vault.reinvest(WETH, WETH.balanceOf(address(vault)), 0, 2000);
        // Second deposit with WETH reward
        amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(WETH), 500, 4000e6 / 2, 0);
        vault.deposit(4000e6, amountOutMin, 2000, 0, 0, address(WETH));
        // Bot reinvest
        // console.log(WETH.balanceOf(address(vault)));
        // console.log(USDC.balanceOf(address(vault)));
        amountOutMin = quoter.quoteExactInputSingle(address(WETH), address(USDC), 500, WETH.balanceOf(address(vault)) / 2, 0);
        vault.reinvest(WETH, WETH.balanceOf(address(vault)), 0, 2000);
        // Various check
        uint userBalance = vault.getUserBalance(address(this), address(WBTC));
        assertEq(userBalance, 5000e6);
        userBalance = vault.getUserBalance(address(this), address(WETH));
        assertEq(userBalance, 4000e6);
        (, uint basePool,,) = reward.rewardInfo(address(WBTC));
        assertEq(basePool, 5000e6);
        (, basePool,,) = reward.rewardInfo(address(WETH));
        assertEq(basePool, 4000e6);
        assertEq(vault.getAllPool(), 5000e6 + 4000e6);
    }

    function testWithdraw() public {
        testDeposit();
        uint withdrawAmt = 2500e6;
        (uint160 sqrtRatioX96,,,,,,) = uniswapV3PoolState.slot0();
        (,,,,,int24 tickLower, int24 tickUpper, uint liquidity,,,,) = nonfungiblePositionManager.positions(vault.tokenId());
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        uint allPool = vault.getAllPool();
        uint liquidity_ = liquidity * withdrawAmt / allPool;
        (uint amount0, uint amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity_));
        amountOutMin = quoter.quoteExactInputSingle(address(WETH), address(USDC), 500, amount0, 0);
        vault.withdraw(2500e6, address(WBTC), amount0 * 95 / 100, amount1 * 95 / 100, amountOutMin);
    }

    // function test() public {
    //     deal(address(USDC), address(this), 4000e6);

    //     uint160 sqrtPriceX96Lower = 2991631685175907615962449;
    //     uint160 sqrtPriceX96Upper = 3663985563520335739962051;
    //     int24[] memory ticks = vault.getTicks(sqrtPriceX96Lower, sqrtPriceX96Upper);
    //     ticks[0] = ticks[0] / 10 * 10;
    //     ticks[1] = ticks[1] / 10 * 10;

    //     USDC.approve(address(vault), type(uint).max);
    //     vault.deposit(4000e6, 0, 2000, ticks[0], ticks[1], address(WBTC));

    //     deal(address(USDC), address(this), 2000e6);
    //     vault.deposit(2000e6, 0, 5000, 0, 0, address(WETH));

    //     vault.reinvest(WETH, WETH.balanceOf(address(vault)), 0, 2000);

    //     sqrtPriceX96Lower = 3173104577100634406797925;
    //     sqrtPriceX96Upper = 3507999100942997269317126;
    //     ticks = vault.getTicks(sqrtPriceX96Lower, sqrtPriceX96Upper);
    //     ticks[0] = ticks[0] / 10 * 10;
    //     ticks[1] = ticks[1] / 10 * 10;
    //     vault.updateTicks(ticks[0], ticks[1], 0, 0, 2000);

    //     // Assume swap
    //     deal(address(WETH), address(this), 1 ether);
    //     WETH.approve(address(swapRouter), type(uint).max);
    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(WETH), address(USDC), 500, address(this), block.timestamp, 1 ether, 0, 0);
    //     swapRouter.exactInputSingle(params);
    //     USDC.approve(address(swapRouter), type(uint).max);
    //     params = ISwapRouter.ExactInputSingleParams(address(USDC), address(WETH), 500, address(this), block.timestamp, USDC.balanceOf(address(this)), 0, 0);
    //     swapRouter.exactInputSingle(params);
    //     deal(address(WETH), address(this), 0);

    //     vault.harvest();

    //     vault.claimReward();
    //     // emit log_uint(WETH.balanceOf(address(this))); // 812335314311

    //     vault.withdraw(vault.getUserBalance(address(WBTC), address(this)), address(WBTC), 0, 0, 0);
    //     // emit log_uint(USDC.balanceOf(address(this))); // 3830.122532
    // }
}

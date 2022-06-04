// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

import "../src/PbUniV3.sol";
import "../src/PbUniV3Reward.sol";
import "../src/PbUniV3Proxy.sol";

import "../interface/ISwapRouter.sol";
import "../interface/IUniswapV3Pool.sol";
import "../interface/IQuoter.sol";
import "../interface/IReward.sol";

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbUniV3Test_DAIUSDC is Test {
    PbUniV3 vault;
    PbUniV3Reward reward;
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable DAI = IERC20Upgradeable(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20Upgradeable USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Pool uniswapV3Pool = IUniswapV3Pool(0xd37Af656Abf91c7f548FfFC0133175b5e4d3d5e6);
    IQuoter quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function setUp() public {
        // Deploy vault
        vault = new PbUniV3();
        PbUniV3Proxy vaultProxy = new PbUniV3Proxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(uniswapV3Pool), // _uniswapV3Pool
                address(this) // _bot
            )
        );
        vault = PbUniV3(address(vaultProxy));
        // Deploy reward
        reward = new PbUniV3Reward();
        PbUniV3Proxy rewardProxy = new PbUniV3Proxy(
            address(reward),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,uint256,address)")),
                address(vault), // _vault
                500, // _yieldFeePerc
                address(1) // _treasury
            )
        );
        reward = PbUniV3Reward(address(rewardProxy));
        // Vault set reward contract
        vault.setReward(IReward(address(reward)));
    }

    function testDeposit() public {
        deal(address(USDC), address(this), 9000e6);
        // Assume get ticks from API
        uint160 sqrtPriceX96Lower = 70863822845718284118440;
        uint160 sqrtPriceX96Upper = 86790103597495589788630;
        (int24 tick0, int24 tick1) = vault.getTicks(sqrtPriceX96Lower, sqrtPriceX96Upper);
        int24 tickSpacing = uniswapV3Pool.tickSpacing();
        tick0 = tick0 / tickSpacing * tickSpacing;
        tick1 = tick1 / tickSpacing * tickSpacing;
        // Approve
        USDC.approve(address(vault), type(uint).max);
        // First deposit with WBTC reward
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(USDC), address(DAI), 500, 5000e6 / 2, 0) * 99 / 100;
        amountsOutMin[1] = 0;
        vault.deposit(5000e6, amountsOutMin, 2000, tick0, tick1, address(WBTC));
        // Bot reinvest
        // console.log(DAI.balanceOf(address(vault))); // 412.052133857179553093
        // console.log(USDC.balanceOf(address(vault))); // 0
        uint amountOutMin = quoter.quoteExactInputSingle(address(DAI), address(USDC), 500, DAI.balanceOf(address(vault)) / 2, 0) * 99 / 100;
        vault.reinvest(DAI, DAI.balanceOf(address(vault)), amountOutMin, 2000);
        // Second deposit with WETH reward
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(USDC), address(DAI), 500, 4000e6 / 2, 0) * 99 / 100;
        vault.deposit(4000e6, amountsOutMin, 2000, 0, 0, address(WETH));
        // Bot reinvest
        // console.log(DAI.balanceOf(address(vault))); // 363.807551673283373660
        // console.log(USDC.balanceOf(address(vault))); // 0
        amountOutMin = quoter.quoteExactInputSingle(address(DAI), address(USDC), 500, DAI.balanceOf(address(vault)) / 2, 0) * 99 / 100;
        vault.reinvest(DAI, DAI.balanceOf(address(vault)), amountOutMin, 2000);
        // Assertion check
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
        // Withdraw (BTC)
        (uint amount0Min, uint amount1Min) = vault.getMinimumAmountsRemoveLiquidity(withdrawAmt, 100);
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(DAI), address(USDC), 500, amount0Min, 0);
        amountsOutMin[1] = 0;
        vault.withdraw(2500e6, address(WBTC), amount0Min, amount1Min, amountsOutMin);
        // Withdraw again
        vault.withdraw(2500e6, address(WBTC), amount0Min, amount1Min, amountsOutMin);
        // Withdraw (ETH)
        (amount0Min, amount1Min) = vault.getMinimumAmountsRemoveLiquidity(4000e6, 100);
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(DAI), address(USDC), 500, amount0Min, 0);
        vault.withdraw(4000e6, address(WETH), amount0Min, amount1Min, amountsOutMin);
        // Assertion check
        // console.log(USDC.balanceOf(address(this))); // 8965.419377
        assertGt(USDC.balanceOf(address(this)), 8950e6);
        assertEq(vault.getAllPool(), 0);
        (,,,,,,,uint liquidity ,,,,) = nonfungiblePositionManager.positions(vault.tokenId());
        assertEq(liquidity, 0);
        assertEq(vault.getUserBalance(address(this), address(WBTC)), 0);
        assertEq(vault.getUserBalance(address(this), address(WETH)), 0);
    }

    function _mockSwap() private {
        deal(address(DAI), address(this), 300000 ether);
        // Swap WETH to USDC
        DAI.approve(address(swapRouter), type(uint).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(DAI), address(USDC), 500, address(this), block.timestamp, DAI.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        // Swap USDC to WETH
        USDC.approve(address(swapRouter), type(uint).max);
        params = ISwapRouter.ExactInputSingleParams(address(USDC), address(DAI), 500, address(this), block.timestamp, USDC.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        deal(address(DAI), address(this), 0); // Reset DAI balanceOf address(this) to 0
    }

    function testHarvest() public {
        testDeposit();
        // Assume swap happening
        _mockSwap();
        uint WBTCAmt1 = WBTC.balanceOf(address(1));
        uint WETHAmt1 = WETH.balanceOf(address(1));
        // Harvest
        vault.harvest();
        // Assertion check
        assertGt(WBTC.balanceOf(address(1)), WBTCAmt1); // treasury fees
        assertGt(WETH.balanceOf(address(1)), WETHAmt1); // treasury fees
        (uint accRewardPerlpToken,, IERC20Upgradeable ibWBTC, uint lastIbRewardTokenAmt) = reward.rewardInfo(address(WBTC));
        assertGt(accRewardPerlpToken, 0);
        uint accRewardPerlpTokenBefWBTC = accRewardPerlpToken;
        assertGt(lastIbRewardTokenAmt, 0);
        IERC20Upgradeable ibWETH;
        (accRewardPerlpToken,, ibWETH, lastIbRewardTokenAmt) = reward.rewardInfo(address(WETH));
        assertGt(accRewardPerlpToken, 0);
        uint accRewardPerlpTokenBefWETH = accRewardPerlpToken;
        assertGt(lastIbRewardTokenAmt, 0);
        assertEq(WBTC.balanceOf(address(reward)), 0);
        assertGt(ibWBTC.balanceOf(address(reward)), 0);
        assertEq(WETH.balanceOf(address(reward)), 0);
        assertGt(ibWETH.balanceOf(address(reward)), 0);
        uint userPendingRewardWBTC1 = vault.getUserPendingReward(address(this), address(WBTC));
        uint userPendingRewardWETH1 = vault.getUserPendingReward(address(this), address(WETH));
        assertGt(userPendingRewardWBTC1, 0);
        assertGt(userPendingRewardWETH1, 0);
        // Assume ibRewardToken increase
        hoax(0x1be2655C587C39610751176ce3C6f3c7018D61c1);
        ibWBTC.transfer(address(reward), 1e5);
        hoax(0x1be2655C587C39610751176ce3C6f3c7018D61c1);
        ibWETH.transfer(address(reward), 1e16);
        // Assume swap happening
        _mockSwap();
        // Harvest again
        vault.harvest();
        // Assertion check
        (accRewardPerlpToken,,, lastIbRewardTokenAmt) = reward.rewardInfo(address(WBTC));
        assertGt(accRewardPerlpToken, accRewardPerlpTokenBefWBTC);
        assertEq(lastIbRewardTokenAmt, ibWBTC.balanceOf(address(reward)));
        (accRewardPerlpToken,,, lastIbRewardTokenAmt) = reward.rewardInfo(address(WETH));
        assertGt(accRewardPerlpToken, accRewardPerlpTokenBefWETH);
        assertEq(lastIbRewardTokenAmt, ibWETH.balanceOf(address(reward)));
        assertGt(vault.getUserPendingReward(address(this), address(WBTC)), userPendingRewardWBTC1);
        assertGt(vault.getUserPendingReward(address(this), address(WETH)), userPendingRewardWETH1);
    }

    function testHarvestToken0Only() public {
        testDeposit();
        // Assume swap happening on token0 only
        deal(address(DAI), address(this), 100000 ether);
        DAI.approve(address(swapRouter), type(uint).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(DAI), address(USDC), 500, address(this), block.timestamp, DAI.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        // Harvest
        vault.harvest();
        // Assertion check
        (uint accRewardPerlpToken,, IERC20Upgradeable ibWBTC,uint lastIbRewardTokenAmt) = reward.rewardInfo(address(WBTC));
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        IERC20Upgradeable ibWETH;
        (accRewardPerlpToken,, ibWETH, lastIbRewardTokenAmt) = reward.rewardInfo(address(WETH));
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        assertEq(WBTC.balanceOf(address(reward)), 0);
        assertGt(ibWBTC.balanceOf(address(reward)), 0);
        assertEq(WETH.balanceOf(address(reward)), 0);
        assertGt(ibWETH.balanceOf(address(reward)), 0);
        assertEq(lastIbRewardTokenAmt, ibWETH.balanceOf(address(reward)));
        assertGt(vault.getUserPendingReward(address(this), address(WBTC)), 0);
        assertGt(vault.getUserPendingReward(address(this), address(WETH)), 0);
    }

    function testHarvestToken1Only() public {
        testDeposit();
        // Assume swap happening on token1 only
        deal(address(USDC), address(this), 100000e6);
        USDC.approve(address(swapRouter), type(uint).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(USDC), address(DAI), 500, address(this), block.timestamp, USDC.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        // Harvest
        vault.harvest();
        // Assertion check
        (uint accRewardPerlpToken,, IERC20Upgradeable ibWBTC, uint lastIbRewardTokenAmt) = reward.rewardInfo(address(WBTC));
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        IERC20Upgradeable ibWETH;
        (accRewardPerlpToken,, ibWETH, lastIbRewardTokenAmt) = reward.rewardInfo(address(WETH));
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        assertEq(WBTC.balanceOf(address(reward)), 0);
        assertGt(ibWBTC.balanceOf(address(reward)), 0);
        assertEq(WETH.balanceOf(address(reward)), 0);
        assertGt(ibWETH.balanceOf(address(reward)), 0);
        assertEq(lastIbRewardTokenAmt, ibWETH.balanceOf(address(reward)));
        assertGt(vault.getUserPendingReward(address(this), address(WBTC)), 0);
        assertGt(vault.getUserPendingReward(address(this), address(WETH)), 0);
    }

    function testClaimRewardWBTC() public {
        testDeposit();
        vault.harvest();
        // Get variable to check later
        (, uint rewardStartAt) = reward.userInfo(address(this), address(WBTC));
        uint userPendingReward = vault.getUserPendingReward(address(this), address(WBTC));
        (,, IERC20Upgradeable ibWBTC, uint lastIbRewardTokenAmt) = reward.rewardInfo(address(WBTC));
        uint WBTCBef = WBTC.balanceOf(address(this));
        // Claim reward
        vault.claimReward();
        // Assertion check
        (, uint rewardStartAt_) = reward.userInfo(address(this), address(WBTC));
        assertEq(rewardStartAt + userPendingReward, rewardStartAt_);
        (,,, uint lastIbRewardTokenAmt_) = reward.rewardInfo(address(WBTC));
        assertEq(lastIbRewardTokenAmt - userPendingReward, lastIbRewardTokenAmt_);
        assertEq(WBTC.balanceOf(address(this)) - WBTCBef, userPendingReward);
        assertEq(ibWBTC.balanceOf(address(reward)), 0);
        assertEq(WBTC.balanceOf(address(reward)), 0);
    }

    function testClaimRewardWETH() public {
        testDeposit();
        vault.harvest();
        // Get variable to check later
        (, uint rewardStartAt) = reward.userInfo(address(this), address(WETH));
        uint userPendingReward = vault.getUserPendingReward(address(this), address(WETH));
        (,, IERC20Upgradeable ibWETH, uint lastIbRewardTokenAmt) = reward.rewardInfo(address(WETH));
        uint WETHBef = WETH.balanceOf(address(this));
        // Claim reward
        vault.claimReward();
        // Assertion check
        (, uint rewardStartAt_) = reward.userInfo(address(this), address(WETH));
        assertEq(rewardStartAt + userPendingReward, rewardStartAt_);
        (,,, uint lastIbRewardTokenAmt_) = reward.rewardInfo(address(WETH));
        assertEq(lastIbRewardTokenAmt - userPendingReward, lastIbRewardTokenAmt_);
        assertEq(WETH.balanceOf(address(this)) - WETHBef, userPendingReward);
        assertEq(ibWETH.balanceOf(address(reward)), 0);
        assertEq(WETH.balanceOf(address(reward)), 0);
    }

    function testUpdateTicks() public {
        testDeposit();
        _mockSwap();
        // Claim first
        vault.claimReward();
        uint WETHClaim1 = WETH.balanceOf(address(this));
        // Get parameters
        (int24 tickLower, int24 tickUpper) = vault.getTicks(75162434512514379355924, 83095197869223157896060);
        int24 tickSpacing = uniswapV3Pool.tickSpacing();
        tickLower = tickLower / tickSpacing * tickSpacing;
        tickUpper = tickUpper / tickSpacing * tickSpacing;
        (uint amount0Min, uint amount1Min) = vault.getMinimumAmountsRemoveLiquidity(vault.getAllPool(), 500);
        // Update ticks
        uint tokenId = vault.tokenId();
        vault.updateTicks(tickLower, tickUpper, amount0Min, amount1Min, 1000);
        // console.log(DAI.balanceOf(address(vault))); // 83905
        // console.log(USDC.balanceOf(address(vault))); // 471.462113
        uint amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(DAI), 500, USDC.balanceOf(address(vault)) / 2, 0) * 95 / 100;
        vault.reinvest(USDC, USDC.balanceOf(address(vault)), amountOutMin, 2000);
        _mockSwap();
        // Claim again
        deal(address(WETH), address(this), 0); // reset WETH balance of address(this) to 0
        vault.claimReward();
        // Assertion check
        assertGt(WETH.balanceOf(address(this)), WETHClaim1);
        assertTrue(vault.tokenId() != tokenId);
    }

    function testPause() public {
        vault.pauseContract();
        // Try deposit
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = 0;
        amountsOutMin[1] = 0;
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(0, amountsOutMin, 0, 0, 0, address(0));
        // Unpause pause contract
        vault.unpauseContract();
        // Try deposit again
        deal(address(USDC), address(this), 1000e6);
        USDC.approve(address(vault), type(uint).max);
        vault.deposit(1000e6, amountsOutMin, 10000, -800000, 800000, address(WBTC));
    }

    function testSetterFunction() public {
        // Vault
        vault.setReward(IReward(address(1)));
        assertEq(address(vault.reward()), address(1));
        vault.setBot(address(1));
        assertEq(vault.bot(), address(1));
        // Reward
        reward.setVault(address(1));
        assertEq(reward.vault(), address(1));
        reward.setYieldFeePerc(1000);
        assertEq(reward.yieldFeePerc(), 1000);
        reward.setTreasury(address(1));
        assertEq(reward.treasury(), address(1));
    }

    function testInitialization() public {
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vault.initialize(IUniswapV3Pool(address(0)), address(0));
        // Reward
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        reward.initialize(address(0), 0, address(0));
    }

    function testAuthorization() public {
        // Vault
        vault.transferOwnership(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.unpauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setReward(IReward(address(this)));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setBot(address(this));
        // Reward
        reward.transferOwnership(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        reward.setVault(address(this));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        reward.setYieldFeePerc(1000);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        reward.setTreasury(address(this));
    }

    function testUpgrade() public {
        // Upgrade vault
        PbUniV3 vault_ = new PbUniV3();
        vault.upgradeTo(address(vault_));
        // Upgrade reward
        PbUniV3Reward reward_ = new PbUniV3Reward();
        reward.upgradeTo(address(reward_));
        // Test run after upgrade
        testClaimRewardWBTC();
    }
}

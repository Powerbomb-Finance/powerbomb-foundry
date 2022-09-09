// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import "../src/PbUniV3Op.sol";
import "../src/PbUniV3OpReward.sol";
import "../src/PbProxy.sol";

import "../interface/ISwapRouter.sol";
import "../interface/IUniswapV3Pool.sol";
import "../interface/IQuoter.sol";
import "../interface/IReward.sol";

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbUniV3OpTest_USDCDAI is Test {
    PbUniV3Op vault;
    PbUniV3OpReward reward;
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable DAI = IERC20Upgradeable(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Pool uniswapV3Pool = IUniswapV3Pool(0xbf16ef186e715668AA29ceF57e2fD7f9D48AdFE6);
    IQuoter quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // // Deploy vault
        // vault = new PbUniV3Op();
        // PbProxy vaultProxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(uniswapV3Pool), // _uniswapV3Pool
        //         address(this) // _bot
        //     )
        // );
        // vault = PbUniV3Op(address(vaultProxy));
        vault = PbUniV3Op(0xAb736E1D68f3A51933E0De23CbC6c1147d0C2934);
        // PbUniV3Op vaultImpl = new PbUniV3Op();
        // hoax(owner);
        // vault.upgradeTo(address(vaultImpl));
        // // Deploy reward
        // reward = new PbUniV3OpReward();
        // PbProxy rewardProxy = new PbProxy(
        //     address(reward),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,uint256,address)")),
        //         address(vault), // _vault
        //         500, // _yieldFeePerc
        //         address(1) // _treasury
        //     )
        // );
        // reward = PbUniV3OpReward(address(rewardProxy));
        reward = PbUniV3OpReward(0xf4c8dd2BB19B9898d65881D88660F8AEBb03064D);
        // // Vault set reward contract
        // vault.setReward(IReward(address(reward)));
    }

    function testDeposit() public {
        deal(address(USDC), address(this), 9000e6);
        // Assume get ticks from API
        uint160 sqrtPriceX96Lower = 78831026366734652303669917531467385;
        uint160 sqrtPriceX96Upper = 79623317895830914510639640423864753;
        (int24 tick0, int24 tick1) = vault.getTicks(sqrtPriceX96Lower, sqrtPriceX96Upper);
        int24 tickSpacing = uniswapV3Pool.tickSpacing();
        tick0 = tick0 / tickSpacing * tickSpacing;
        tick1 = tick1 / tickSpacing * tickSpacing;
        // Approve
        USDC.approve(address(vault), type(uint).max);
        // First deposit with WBTC reward
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(USDC), address(DAI), 100, 5000e6 / 2, 0) * 99 / 100;
        amountsOutMin[1] = 0;
        vault.deposit(5000e6, amountsOutMin, 2000, tick0, tick1, address(WBTC));
        // Bot reinvest
        // console.log(DAI.balanceOf(address(vault))); // 0
        // console.log(USDC.balanceOf(address(vault))); // 61.479873
        // uint amountOutMin = quoter.quoteExactInputSingle(address(DAI), address(USDC), 100, DAI.balanceOf(address(vault)) / 2, 0) * 99 / 100;
        // vault.reinvest(DAI, DAI.balanceOf(address(vault)), amountOutMin, 2000);
        // Second deposit with WETH reward
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(USDC), address(DAI), 100, 4000e6 / 2, 0) * 99 / 100;
        vault.deposit(4000e6, amountsOutMin, 2000, 0, 0, address(WETH));
        // Bot reinvest
        // console.log(DAI.balanceOf(address(vault))); // 0
        // console.log(USDC.balanceOf(address(vault))); // 110.675659
        uint amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(DAI), 100, USDC.balanceOf(address(vault)) / 2, 0) * 99 / 100;
        // hoax(owner);
        vm.startPrank(owner);
        vault.reinvest(USDC, USDC.balanceOf(address(vault)), amountOutMin, 2000);
        vm.stopPrank();
        // console.log(DAI.balanceOf(address(vault))); // 0
        // console.log(USDC.balanceOf(address(vault))); // 1.361345
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
        // Withdraw (BTC)
        // (uint amount0Min, uint amount1Min) = vault.getMinimumAmountsRemoveLiquidity(2500e6, 100);
        uint amount0Min = 2500e6 / 2 * 95 / 100;
        uint amount1Min = amount0Min * 1e12; // DAI 18 decimals
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(DAI), address(USDC), 100, amount1Min, 0);
        amountsOutMin[1] = 0;
        vault.withdraw(2500e6, address(WBTC), amount0Min, amount1Min, amountsOutMin);
        // Withdraw again
        vault.withdraw(2500e6, address(WBTC), amount0Min, amount1Min, amountsOutMin);
        // Withdraw (ETH)
        // (amount0Min, amount1Min) = vault.getMinimumAmountsRemoveLiquidity(4000e6, 100);
        amount0Min = 4000e6 / 2 * 95 / 100;
        amount1Min = amount0Min * 1e12; // DAI 18 decimals
        amountsOutMin[0] = quoter.quoteExactInputSingle(address(DAI), address(USDC), 100, amount1Min, 0);
        vault.withdraw(4000e6, address(WETH), amount0Min, amount1Min, amountsOutMin);
        // Assertion check
        // console.log(USDC.balanceOf(address(this))); // 8989.229212
        assertGt(USDC.balanceOf(address(this)), 8980e6);
        assertEq(vault.getAllPool(), 0);
        (,,,,,,,uint liquidity ,,,,) = nonfungiblePositionManager.positions(vault.tokenId());
        assertEq(liquidity, 0);
        assertEq(vault.getUserBalance(address(this), address(WBTC)), 0);
        assertEq(vault.getUserBalance(address(this), address(WETH)), 0);
    }

    function _mockSwap() private {
        deal(address(DAI), address(this), 1_000_000 ether);
        // Swap DAI to USDC
        DAI.approve(address(swapRouter), type(uint).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(DAI), address(USDC), 100, address(this), block.timestamp, DAI.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        // console.log(DAI.balanceOf(address(this)));
        // console.log(USDC.balanceOf(address(this)));
        // Swap USDC to DAI
        USDC.approve(address(swapRouter), type(uint).max);
        params = ISwapRouter.ExactInputSingleParams(address(USDC), address(DAI), 100, address(this), block.timestamp, USDC.balanceOf(address(this)), 0, 0);
        swapRouter.exactInputSingle(params);
        // console.log(DAI.balanceOf(address(this)));
        // console.log(USDC.balanceOf(address(this)));
        deal(address(DAI), address(this), 0); // Reset DAI balanceOf address(this) to 0
    }

    function testHarvest() public {
        testDeposit();
        // Assume swap happening
        _mockSwap();
        uint WBTCAmt1 = WBTC.balanceOf(owner);
        uint WETHAmt1 = WETH.balanceOf(owner);
        // Assume OP reward from Aave
        deal(address(OP), address(reward), 1 ether);
        // Harvest
        vault.harvest();
        // Assertion check
        assertGt(WBTC.balanceOf(owner), WBTCAmt1); // treasury fees
        assertGt(WETH.balanceOf(owner), WETHAmt1); // treasury fees
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
        hoax(0xC948eB5205bDE3e18CAc4969d6ad3a56ba7B2347);
        ibWBTC.transfer(address(reward), 1e5);
        hoax(0xC948eB5205bDE3e18CAc4969d6ad3a56ba7B2347);
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
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(DAI), address(USDC), 100, address(this), block.timestamp, DAI.balanceOf(address(this)), 0, 0);
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
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(address(USDC), address(DAI), 100, address(this), block.timestamp, USDC.balanceOf(address(this)), 0, 0);
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
        (int24 tickLower, int24 tickUpper) = vault.getTicks(79188538524532033966444101902787937, 79267766696949822951113378804207684);
        int24 tickSpacing = uniswapV3Pool.tickSpacing();
        tickLower = tickLower / tickSpacing * tickSpacing;
        tickUpper = tickUpper / tickSpacing * tickSpacing;
        // (uint amount0Min, uint amount1Min) = vault.getMinimumAmountsRemoveLiquidity(vault.getAllPool(), 500);
        uint amount0Min = vault.getAllPool() / 2 * 95 / 100;
        uint amount1Min = amount0Min * 1e12; // DAI 18 decimals
        // Update ticks
        uint tokenId = vault.tokenId();
        hoax(owner);
        vault.updateTicks(tickLower, tickUpper, amount0Min, amount1Min, 2500);
        // console.log(DAI.balanceOf(address(vault))); // 79
        // console.log(USDC.balanceOf(address(vault))); // 1089.978817
        uint amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(DAI), 100, USDC.balanceOf(address(vault)) / 2, 0) * 95 / 100;
        vm.startPrank(owner);
        vault.reinvest(USDC, USDC.balanceOf(address(vault)), amountOutMin, 3000);
        amountOutMin = quoter.quoteExactInputSingle(address(USDC), address(DAI), 100, USDC.balanceOf(address(vault)) / 2, 0) * 95 / 100;
        vault.reinvest(USDC, USDC.balanceOf(address(vault)), amountOutMin, 3000);
        vm.stopPrank();
        // console.log(DAI.balanceOf(address(vault))); // 409
        // console.log(USDC.balanceOf(address(vault))); // 22.448165
        _mockSwap();
        // Claim again
        // deal(address(WETH), address(this), 0); // reset WETH balance of address(this) to 0
        vault.claimReward();
        // Assertion check
        assertGt(WETH.balanceOf(address(this)), WETHClaim1);
        assertTrue(vault.tokenId() != tokenId);
    }

    function testPause() public {
        hoax(owner);
        vault.pauseContract();
        // Try deposit
        uint[] memory amountsOutMin = new uint[](2);
        amountsOutMin[0] = 0;
        amountsOutMin[1] = 0;
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(0, amountsOutMin, 0, 0, 0, address(0));
        // Unpause pause contract
        hoax(owner);
        vault.unpauseContract();
        // Try deposit again
        deal(address(USDC), address(this), 1000e6);
        USDC.approve(address(vault), type(uint).max);
        vault.deposit(1000e6, amountsOutMin, 10000, -800000, 800000, address(WBTC));
    }

    function testSetterFunction() public {
        // Vault
        startHoax(owner);
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
        startHoax(owner);
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
        PbUniV3Op vault_ = new PbUniV3Op();
        hoax(owner);
        vault.upgradeTo(address(vault_));
        // Upgrade reward
        PbUniV3OpReward reward_ = new PbUniV3OpReward();
        hoax(owner);
        reward.upgradeTo(address(reward_));
        // Test run after upgrade
        testClaimRewardWBTC();
    }
}

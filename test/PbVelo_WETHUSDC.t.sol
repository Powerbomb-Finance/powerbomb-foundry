// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/PbVelo.sol";
import "../src/PbVeloProxy.sol";
import "../script/Deploy.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IChainLink.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbVeloTest_WETHUSDC is Test {
    PbVelo vault;
    Deploy deploy;
    IWETH WETH = IWETH(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable rewardToken;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    function setUp() public {
        vault = new PbVelo();
        PbVeloProxy proxy = new PbVeloProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address,address,address,address,address,address)")),
                address(VELO), // _VELO
                0xE2CEc8aB811B648bA7B1691Ce08d5E800Dd0a60a, // _gauge
                address(WETH), // _rewardToken
                // address(WBTC), // _rewardToken
                0x794a61358D6845594F94dc1DB02A252b5b4814aD, // _lendingPool
                address(router), // _router
                address(WETH), // _WETH
                0x13e3Ee699D1909E989722E753853AE30b17e08c5, // _WETHPriceFeed
                address(1) // _treasury
            )
        );
        vault = PbVelo(payable(address(proxy)));

        token0 = IERC20Upgradeable(vault.token0()); // WETH
        token1 = IERC20Upgradeable(vault.token1()); // USDC
        rewardToken = WETH;
        // rewardToken = WBTC;
    }

    function testDeposit() public {
        // Deposit token0
        deal(address(token0), address(this), 10 ether);
        token0.approve(address(vault), type(uint).max);
        (uint amountOut,) = router.getAmountOut(token0.balanceOf(address(this)) / 2, address(token0), address(token1));
        vault.deposit(token0, token0.balanceOf(address(this)), amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this)));
        // console.log(token1.balanceOf(address(this)));

        // Deposit token1
        deal(address(token1), address(this), 10_000e6);
        token1.approve(address(vault), type(uint).max);
        (amountOut,) = router.getAmountOut(token1.balanceOf(address(this)) / 2, address(token1), address(token0));
        vault.deposit(token1, token1.balanceOf(address(this)), amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this)));
        // console.log(token1.balanceOf(address(this)));

        // Deposit ETH
        (amountOut,) = router.getAmountOut(10 ether / 2, address(token0), address(token1));
        vault.deposit{value: 10 ether}(token0, 10 ether, amountOut * 95 / 100);

        // Deposit LP
        IERC20Upgradeable lpToken = IERC20Upgradeable(0x79c912FEF520be002c2B6e57EC4324e260f38E50);
        deal(address(lpToken), address(this), 0.000001 ether);
        lpToken.approve(address(vault), type(uint).max);
        vault.deposit(lpToken, lpToken.balanceOf(address(this)), 0);

        uint userBalance = vault.getUserBalance(address(this));
        assertGt(userBalance, 0);
        // console.log(userBalance);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(address(this));
        assertGt(userBalanceInUSD, 0);
        // console.log(userBalanceInUSD);
        uint pricePerFullShareInUSD = vault.getPricePerFullShareInUSD();
        assertGt(pricePerFullShareInUSD, 0);
        // console.log(pricePerFullShareInUSD);
        uint allPool = vault.getAllPool();
        assertGt(allPool, 0);
        // console.log(allPool);
        uint allPoolInUSD = vault.getAllPoolInUSD();
        assertGt(allPoolInUSD, 0);
        // console.log(allPoolInUSD);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint userBalance = vault.getUserBalance(address(this)) / 3;

        // Withdraw WETH
        (uint amount0, uint amount1) = router.quoteRemoveLiquidity(address(WETH), address(TOMB), vault.stable(), userBalance);
        (uint amountOutMin,) = router.getAmountOut(amount1, address(TOMB), address(WETH));
        uint WETHBef = WETH.balanceOf(address(this));
        vault.withdraw(WETH, userBalance, amountOutMin * 4 / 5); // 20% slippage
        assertGt(WETH.balanceOf(address(this)), WETHBef);

        // Withdraw TOMB
        (amountOutMin,) = router.getAmountOut(amount0, address(WETH), address(TOMB));
        uint TOMBBef = TOMB.balanceOf(address(this));
        vault.withdraw(TOMB, userBalance, amountOutMin * 4 / 5);
        assertGt(TOMB.balanceOf(address(this)), TOMBBef);

        // Withdraw ETH
        (amountOutMin,) = router.getAmountOut(amount1, address(TOMB), address(WETH));
        uint ETHBef = address(this).balance;
        vault.withdrawETH(WETH, userBalance, amountOutMin * 4 / 5);
        assertGt(address(this).balance, ETHBef);

        // withdraw LP

        userBalance = vault.getUserBalance(address(this));
        assertEq(userBalance, 1);
        // console.log(userBalance);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(address(this));
        assertEq(userBalanceInUSD, 0);
        // console.log(userBalanceInUSD);
        uint allPool = vault.getAllPool();
        assertEq(allPool, 1);
        // console.log(allPool);
        uint allPoolInUSD = vault.getAllPoolInUSD();
        assertEq(allPoolInUSD, 0);
        // console.log(allPoolInUSD);
    }

    receive() external payable {}

    // function testHarvest() public {
    //     testDeposit();
    //     uint rewardTokenBef = rewardToken.balanceOf(address(1));

    //     // Assume reward
    //     deal(address(VELO), address(vault), 100 ether);

    //     // Harvest
    //     vault.harvest();

    //     // Various check
    //     assertGt(rewardToken.balanceOf(address(1)), rewardTokenBef);
    //     (, IERC20Upgradeable ibRewardToken, uint lastIbRewardTokenAmt, uint accRewardPerlpToken) = vault.reward();
    //     assertGt(accRewardPerlpToken, 0);
    //     assertGt(lastIbRewardTokenAmt, 0);
    //     assertEq(WBTC.balanceOf(address(vault)), 0);
    //     assertEq(WETH.balanceOf(address(vault)), 0);
    //     assertGt(ibRewardToken.balanceOf(address(vault)), 0);
    //     // console.log(ibRewardToken.balanceOf(address(vault)));
    //     uint userPendingReward = vault.getUserPendingReward(address(this));
    //     // console.log(userPendingReward);
    //     assertGt(userPendingReward, 0);

    //     // Assume increase ibRewardToken
    //     hoax(0x8C39f76b8A25563d84D8bbad76443b0E9CbB3D01); // ibRewardToken holder
    //     ibRewardToken.transfer(address(vault), 1 ether);
    //     // hoax(0xd28F814fAA0E549c1c58ea99D5477aC75ae37633); // ibRewardToken holder
    //     // ibRewardToken.transfer(address(vault), 100000);

    //     // Harvest again
    //     uint ibRewardTokenBef = ibRewardToken.balanceOf(address(vault));
    //     vault.harvest();

    //     // Check accRewardPerlpToken
    //     uint accRewardPerlpTokenBef = accRewardPerlpToken;
    //     (,, lastIbRewardTokenAmt, accRewardPerlpToken) = vault.reward();
    //     assertGt(accRewardPerlpToken, accRewardPerlpTokenBef);
    //     assertEq(ibRewardTokenBef, lastIbRewardTokenAmt);

    //     // Check userPendingReward again
    //     uint userPendingRewardBef = userPendingReward;
    //     userPendingReward = vault.getUserPendingReward(address(this));
    //     // console.log(userPendingReward);
    //     assertGt(userPendingReward, userPendingRewardBef);
    // }

    // function testClaim() public {
    //     testHarvest();
    //     (, uint rewardStartAt) = vault.userInfo(address(this));
    //     (,, uint lastIbRewardTokenAmt,) = vault.reward();
    //     uint rewardTokenBef = rewardToken.balanceOf(address(this));

    //     // Claim
    //     vault.claimReward(address(this));

    //     // Various check
    //     uint rewardStartAtBef = rewardStartAt;
    //     (, rewardStartAt) = vault.userInfo(address(this));
    //     assertGt(rewardStartAt, rewardStartAtBef);
    //     uint lastIbRewardTokenAmtBef = lastIbRewardTokenAmt;
    //     (,, lastIbRewardTokenAmt,) = vault.reward();
    //     assertLt(lastIbRewardTokenAmt, lastIbRewardTokenAmtBef);
    //     assertGt(rewardToken.balanceOf(address(this)), rewardTokenBef);
    // }

    // function testPauseContract() public {
    //     // Pause contract
    //     vault.pauseContract();

    //     // Test deposit
    //     vm.expectRevert(bytes("Pausable: paused"));
    //     vault.deposit(WETH, 1000 ether, 0);

    //     // Unpause contract
    //     vault.unpauseContract();

    //     // Test deposit again
    //     deal(address(WETH), address(this), 1000 ether);
    //     WETH.approve(address(vault), type(uint).max);
    //     vault.deposit(WETH, 1000 ether, 0);
    // }

    // function testAuthorization() public {
    //     vault.transferOwnership(address(1));
    //     assertEq(vault.owner(), address(1));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vault.setTreasury(address(this));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vault.setYieldFeePerc(0);
    // }

    // function testUpgrade() public {
    //     PbVelo vault_ = new PbVelo();
    //     vault.upgradeTo(address(vault_));
    // }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/PbVelo.sol";
import "../src/PbProxy.sol";
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
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable rewardToken;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        vault = new PbVelo();
        PbProxy proxy = new PbProxy(
            address(vault),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                0xE2CEc8aB811B648bA7B1691Ce08d5E800Dd0a60a, // _gauge
                address(WETH), // _rewardToken
                address(owner) // _treasury
            )
        );
        vault = PbVelo(payable(address(proxy)));

        token0 = IERC20Upgradeable(vault.token0()); // WETH
        token1 = IERC20Upgradeable(vault.token1()); // USDC
        lpToken = IERC20Upgradeable(vault.lpToken());
        rewardToken = WETH;
    }

    function testDeposit() public {
        // Deposit token0
        deal(address(token0), address(this), 10 ether);
        token0.approve(address(vault), type(uint).max);
        (uint amountOut,) = router.getAmountOut(token0.balanceOf(address(this)) / 2, address(token0), address(token1));
        // console.log(amountOut); // 8129.612070
        vault.deposit(token0, token0.balanceOf(address(this)), amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 0
        // console.log(token1.balanceOf(address(this))); // 14.794953

        (uint reserveA, uint reserveB) = router.getReserves(address(token0), address(token1), vault.stable());
        uint amountA = 5 ether;
        uint amountB = amountA * reserveB / reserveA;
        console.log(amountB); // 8147.692750

        (uint amountA, uint amountB,) = router.quoteAddLiquidity(
            address(token0),
            address(token1),
            vault.stable(),
            5 ether,
            type(uint).max
        );
        console.log(amountA); // 5.000000000000000000
        console.log(amountB); // 8147.692750

        IPair pair = vault.lpToken();
        uint amountIn = 5 ether;
        uint amountOut = amountIn * reserveB / (reserveA + amountIn);
        console.log(amountOut); // 8131.235033

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
        uint userBalance = vault.getUserBalance(address(this)) / 4;

        // Withdraw token0
        (uint amount0, uint amount1) = router.quoteRemoveLiquidity(address(token0), address(token1), vault.stable(), userBalance);
        (uint amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        uint token0Bef = token0.balanceOf(address(this));
        vault.withdraw(token0, userBalance, amountOut * 95 / 100);
        assertGt(token0.balanceOf(address(this)), token0Bef);

        // Withdraw token1
        (amountOut,) = router.getAmountOut(amount0, address(token0), address(token1));
        uint token1Bef = token1.balanceOf(address(this));
        vault.withdraw(token1, userBalance, amountOut * 95 / 100);
        assertGt(token1.balanceOf(address(this)), token1Bef);

        // Withdraw ETH
        (amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        uint ETHBef = address(this).balance;
        vault.withdrawETH(token0, userBalance, amountOut * 95 / 100);
        assertGt(address(this).balance, ETHBef);

        // withdraw LP
        uint lpTokenBef = lpToken.balanceOf(address(this));
        vault.withdraw(lpToken, userBalance, 0);
        assertGt(lpToken.balanceOf(address(this)), lpTokenBef);

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

    function testHarvest() public {
        testDeposit();
        uint rewardTokenBef = rewardToken.balanceOf(address(1));
        // Assume reward
        deal(address(VELO), address(vault), 1000 ether);
        // Harvest
        vault.harvest();
        // Assertion check
        assertGt(rewardToken.balanceOf(address(1)), rewardTokenBef);
        (, IERC20Upgradeable ibRewardToken, uint lastIbRewardTokenAmt, uint accRewardPerlpToken) = vault.reward();
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        assertEq(USDC.balanceOf(address(vault)), 0);
        assertEq(WETH.balanceOf(address(vault)), 0);
        assertGt(ibRewardToken.balanceOf(address(vault)), 0);
        // console.log(ibRewardToken.balanceOf(address(vault)));
        uint userPendingReward = vault.getUserPendingReward(address(this));
        // console.log(userPendingReward);
        assertGt(userPendingReward, 0);
        // Assume increase ibRewardToken
        // hoax(0x39DE56518e136d472Ef9645e7D6E1F7c6C8Ed37b); // ibRewardToken holder
        // ibRewardToken.transfer(address(vault), 0.01 ether); // WETH
        hoax(0x44b62a2c532bD4a4A3805CFc462284D8F41f64C8); // ibRewardToken holder
        ibRewardToken.transfer(address(vault), 10e6); // USDC
        // Harvest again
        uint ibRewardTokenBef = ibRewardToken.balanceOf(address(vault));
        vault.harvest();
        // Check accRewardPerlpToken
        uint accRewardPerlpTokenBef = accRewardPerlpToken;
        (,, lastIbRewardTokenAmt, accRewardPerlpToken) = vault.reward();
        assertGt(accRewardPerlpToken, accRewardPerlpTokenBef);
        assertEq(ibRewardTokenBef, lastIbRewardTokenAmt);
        // Check userPendingReward again
        uint userPendingRewardBef = userPendingReward;
        userPendingReward = vault.getUserPendingReward(address(this));
        // console.log(userPendingReward);
        assertGt(userPendingReward, userPendingRewardBef);
    }

    function testClaim() public {
        testHarvest();
        (, uint rewardStartAt) = vault.userInfo(address(this));
        (,, uint lastIbRewardTokenAmt,) = vault.reward();
        uint rewardTokenBef = rewardToken.balanceOf(address(this));
        // Claim
        vault.claimReward(address(this));
        // Assertion check
        uint rewardStartAtBef = rewardStartAt;
        (, rewardStartAt) = vault.userInfo(address(this));
        assertGt(rewardStartAt, rewardStartAtBef);
        uint lastIbRewardTokenAmtBef = lastIbRewardTokenAmt;
        (,, lastIbRewardTokenAmt,) = vault.reward();
        assertLt(lastIbRewardTokenAmt, lastIbRewardTokenAmtBef);
        assertGt(rewardToken.balanceOf(address(this)), rewardTokenBef);
    }

    function testPauseContract() public {
        // Pause contract
        vault.pauseContract();
        // Test deposit
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(WETH, 1000 ether, 0);
        // Unpause contract
        vault.unpauseContract();
        // Test deposit again
        deal(address(WETH), address(this), 1000 ether);
        WETH.approve(address(vault), type(uint).max);
        vault.deposit(WETH, 1000 ether, 0);
    }

    function testAuthorization() public {
        vault.transferOwnership(address(1));
        assertEq(vault.owner(), address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setTreasury(address(this));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setYieldFeePerc(0);
    }

    function testUpgrade() public {
        PbVelo vault_ = new PbVelo();
        vault.upgradeTo(address(vault_));
    }
}

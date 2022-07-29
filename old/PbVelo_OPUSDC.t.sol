// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

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

contract PbVeloTest_OPUSDC is Test {
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

    function setUp() public {
        vault = new PbVelo();
        PbProxy proxy = new PbProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address,address,address,address,address,address)")),
                address(VELO), // _VELO
                0x0299d40E99F2a5a1390261f5A71d13C3932E214C, // _gauge
                // address(WETH), // _rewardToken
                address(USDC), // _rewardToken
                0x794a61358D6845594F94dc1DB02A252b5b4814aD, // _lendingPool
                address(router), // _router
                address(WETH), // _WETH
                0x13e3Ee699D1909E989722E753853AE30b17e08c5, // _WETHPriceFeed
                address(1) // _treasury
            )
        );
        vault = PbVelo(payable(address(proxy)));

        token0 = IERC20Upgradeable(vault.token0()); // OP
        token1 = IERC20Upgradeable(vault.token1()); // USDC
        lpToken = IERC20Upgradeable(vault.lpToken());
        // rewardToken = WETH;
        rewardToken = USDC;
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
        uint userBalance = vault.getUserBalance(address(this)) / 3;

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

        // withdraw LP
        uint lpTokenBef = lpToken.balanceOf(address(this));
        vault.withdraw(lpToken, userBalance, 0);
        assertGt(lpToken.balanceOf(address(this)), lpTokenBef);

        userBalance = vault.getUserBalance(address(this));
        assertEq(userBalance, 2);
        // console.log(userBalance);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(address(this));
        assertEq(userBalanceInUSD, 0);
        // console.log(userBalanceInUSD);
        uint allPool = vault.getAllPool();
        assertEq(allPool, 2);
        // console.log(allPool);
        uint allPoolInUSD = vault.getAllPoolInUSD();
        assertEq(allPoolInUSD, 0);
        // console.log(allPoolInUSD);
    }

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
        vault.deposit(USDC, 1000 ether, 0);
        // Unpause contract
        vault.unpauseContract();
        // Test deposit again
        deal(address(USDC), address(this), 1000 ether);
        USDC.approve(address(vault), type(uint).max);
        vault.deposit(USDC, 1000 ether, 0);
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

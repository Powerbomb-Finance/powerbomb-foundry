// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/PbWeve.sol";
import "../src/PbWeveProxy.sol";
import "../script/Deploy.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IChainLink.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbWeveTest is Test {
    PbWeve vault;
    Deploy deploy;
    IWETH WETH;
    IERC20Upgradeable WBTC;
    IERC20Upgradeable WEVE;
    IERC20Upgradeable TOMB;
    IERC20Upgradeable rewardToken;
    IRouter router = IRouter(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    function setUp() public {
        WETH = IWETH(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
        WBTC = IERC20Upgradeable(0x321162Cd933E2Be498Cd2267a90534A804051b11);
        TOMB = IERC20Upgradeable(0x6c021Ae822BEa943b2E66552bDe1D2696a53fbB7);
        WEVE = IERC20Upgradeable(0x888EF71766ca594DED1F0FA3AE64eD2941740A20);

        vault = new PbWeve();
        PbWeveProxy proxy = new PbWeveProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address,address,address,address,address,address)")),
                0x888EF71766ca594DED1F0FA3AE64eD2941740A20, // _WEVE
                0x1d1A1871d1830D4b5087212c820E5f1252379c2c, // _gauge
                address(WETH), // _rewardToken
                // address(WBTC), // _rewardToken
                0x794a61358D6845594F94dc1DB02A252b5b4814aD, // _lendingPool
                0xa38cd27185a464914D3046f0AB9d43356B34829D, // _router
                address(WETH), // _WETH
                0xf4766552D15AE4d256Ad41B6cf2933482B0680dc, // _WETHPriceFeed
                address(1) // _treasury
            )
        );
        vault = PbWeve(payable(address(proxy)));

        rewardToken = WETH;
        // rewardToken = WBTC;
    }

    function testDeposit() public {
        // Deposit WETH
        deal(address(WETH), address(this), 1000 ether);
        WETH.approve(address(vault), type(uint).max);
        (uint amountOutMin,) = router.getAmountOut(500 ether, address(WETH), address(TOMB));
        vault.deposit(WETH, 1000 ether, amountOutMin);
        // console.log(WETH.balanceOf(address(this)));
        // console.log(TOMB.balanceOf(address(this)));

        // Deposit TOMB
        deal(address(TOMB), address(this), 1000 ether);
        TOMB.approve(address(vault), type(uint).max);
        (amountOutMin,) = router.getAmountOut(500 ether, address(TOMB), address(WETH));
        vault.deposit(TOMB, 1000 ether, amountOutMin);
        // console.log(WETH.balanceOf(address(this)));
        // console.log(TOMB.balanceOf(address(this)));

        // Deposit ETH
        (amountOutMin,) = router.getAmountOut(500 ether, address(WETH), address(TOMB));
        vault.deposit{value: 1000 ether}(WETH, 1000 ether, amountOutMin);

        // Deposit LP
        IERC20Upgradeable lpToken = IERC20Upgradeable(0x60a861Cd30778678E3d613db96139440Bd333143);
        deal(address(lpToken), address(this), 1000 ether);
        lpToken.approve(address(vault), type(uint).max);
        vault.deposit(lpToken, 1000 ether, 0);

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
        deal(address(WEVE), address(vault), 100 ether);

        // Harvest
        vault.harvest();

        // Various check
        assertGt(rewardToken.balanceOf(address(1)), rewardTokenBef);
        (, IERC20Upgradeable ibRewardToken, uint lastIbRewardTokenAmt, uint accRewardPerlpToken) = vault.reward();
        assertGt(accRewardPerlpToken, 0);
        assertGt(lastIbRewardTokenAmt, 0);
        assertEq(WBTC.balanceOf(address(vault)), 0);
        assertEq(WETH.balanceOf(address(vault)), 0);
        assertGt(ibRewardToken.balanceOf(address(vault)), 0);
        // console.log(ibRewardToken.balanceOf(address(vault)));
        uint userPendingReward = vault.getUserPendingReward(address(this));
        // console.log(userPendingReward);
        assertGt(userPendingReward, 0);

        // Assume increase ibRewardToken
        hoax(0x8C39f76b8A25563d84D8bbad76443b0E9CbB3D01); // ibRewardToken holder
        ibRewardToken.transfer(address(vault), 1 ether);
        // hoax(0xd28F814fAA0E549c1c58ea99D5477aC75ae37633); // ibRewardToken holder
        // ibRewardToken.transfer(address(vault), 100000);

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

        // Various check
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
        PbWeve vault_ = new PbWeve();
        vault.upgradeTo(address(vault_));
    }
}

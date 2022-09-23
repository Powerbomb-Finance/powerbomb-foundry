// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PbVelo.sol";
import "../src/PbProxy.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IChainLink.sol";
import "../interfaces/IPair.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract WETHSETHTest is Test {
    PbVelo vaultUSDC;
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aUSDC;
    IERC20Upgradeable aWETH;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    // address owner = address(this);

    function setUp() public {
        // PbVelo vaultImpl = new PbVelo();

        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0x101D5e5651D7f949154258C1C7516da1eC273476, // _gauge
        //         address(USDC), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultUSDC = PbVelo(payable(address(proxy)));
        vaultUSDC = PbVelo(payable(0xcba7864134e1A5326b817676ad5302A009c84d68));
        PbVelo vaultImpl = new PbVelo();
        hoax(owner);
        vaultUSDC.upgradeTo(address(vaultImpl));

        token0 = IERC20Upgradeable(vaultUSDC.token0());
        token1 = IERC20Upgradeable(vaultUSDC.token1());
        lpToken = IERC20Upgradeable(vaultUSDC.lpToken());
        (, aUSDC,,) = vaultUSDC.reward();
    }

    function test() public {
        vaultUSDC.deposit{value: 4 ether}(WETH, 4 ether, getSwapPerc(address(WETH)), 0);
        // console.log(vaultUSDC.getUserBalanceInUSD(address(this)));
        console.log(token0.balanceOf(address(this))); // 1
        console.log(token1.balanceOf(address(this))); // 0.001986591509056049
        // console.log(lpToken.balanceOf(address(this)));
    }

    // function testDeposit() public {
    //     // Deposit token0 for USDC reward
    //     uint swapPerc = getSwapPerc(address(token0));
    //     (uint amountOut,) = router.getAmountOut(
    //         10 ether * swapPerc / 1000, address(token0), address(token1));
    //     vaultUSDC.deposit{value: 10 ether}(token0, 10 ether, swapPerc, amountOut * 95 / 100);
    //     // console.log(token0.balanceOf(address(this))); // 0.021111462207938377
    //     // console.log(token1.balanceOf(address(this))); // 0

    //     // Deposit token1 for USDC reward
    //     // deal(address(token1), address(this), 10 ether);
    //     address SETHHolder = 0x12478d1a60a910C9CbFFb90648766a2bDD5918f5;
    //     hoax(SETHHolder);
    //     token1.transfer(address(this), 10 ether);
    //     swapPerc = getSwapPerc(address(token1));
    //     token1.approve(address(vaultUSDC), type(uint).max);
    //     (amountOut,) = router.getAmountOut(
    //         token1.balanceOf(address(this)) * swapPerc / 1000, address(token1), address(token0));
    //     vaultUSDC.deposit(token1, token1.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
    //     // console.log(token0.balanceOf(address(this))); // 0.056510491632296631
    //     // console.log(token1.balanceOf(address(this))); // 0

    //     // Deposit LP for USDC reward
    //     deal(address(lpToken), address(this), 1 ether);
    //     lpToken.approve(address(vaultUSDC), type(uint).max);
    //     vaultUSDC.deposit(lpToken, lpToken.balanceOf(address(this)), 0, 0);

    //     // Assertion check
    //     assertGt(vaultUSDC.getUserBalance(address(this)), 0);
    //     // console.log(vaultUSDC.getUserBalance(address(this))); // 7.653347766553351280
    //     assertGt(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
    //     // console.log(vaultUSDC.getUserBalanceInUSD(address(this))); // 39200.428922
    //     assertGt(vaultUSDC.getPricePerFullShareInUSD(), 0);
    //     // console.log(vaultUSDC.getPricePerFullShareInUSD());
    //     assertGt(vaultUSDC.getAllPool(), 0);
    //     // console.log(vaultUSDC.getAllPool());
    //     assertGt(vaultUSDC.getAllPoolInUSD(), 0);
    //     // console.log(vaultUSDC.getAllPoolInUSD());
    //     assertEq(token0.balanceOf(address(vaultUSDC)), 0);
    //     assertEq(token1.balanceOf(address(vaultUSDC)), 0);
    //     assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
    // }

    // function testWithdraw() public {
    //     testDeposit();
    //     vm.roll(block.number + 1);

    //     // withdraw LP from USDC reward
    //     vaultUSDC.withdraw(lpToken, 1 ether, 0);

    //     // // Withdraw token1 from USDC reward
    //     uint userBalance = vaultUSDC.getUserBalance(address(this)) / 2;
    //     (uint amount0,) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultUSDC.stable(), userBalance);
    //     (uint amountOut,) = router.getAmountOut(amount0, address(token0), address(token1));
    //     vaultUSDC.withdraw(token1, userBalance, amountOut * 95 / 100);

    //     // Withdraw token0 from USDC reward
    //     uint ethBal = address(this).balance;
    //     userBalance = vaultUSDC.getUserBalance(address(this));
    //     (,uint amount1) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultUSDC.stable(), userBalance);
    //     (amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
    //     vaultUSDC.withdraw(token0, userBalance, amountOut * 95 / 100);

    //     // Assertion check
    //     assertEq(vaultUSDC.getAllPool(), 0);
    //     assertEq(vaultUSDC.getAllPoolInUSD(), 0);
    //     assertEq(vaultUSDC.getUserBalance(address(this)), 0);
    //     assertEq(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
    //     // console.log(lpToken.balanceOf(address(this))); // 1.000000000000000000
    //     // console.log(address(this).balance - ethBal); // 9.998889683603234682
    //     // console.log(token1.balanceOf(address(this))); // 9.940934375666410565
    //     assertEq(token0.balanceOf(address(vaultUSDC)), 0);
    //     assertEq(token1.balanceOf(address(vaultUSDC)), 0);
    //     assertEq(address(vaultUSDC).balance, 0);
    //     assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
    //     assertGt(address(this).balance - ethBal, 0);
    //     // assertGt(token1.balanceOf(address(this)), 0);
    //     assertGt(lpToken.balanceOf(address(this)), 0);
    // }

    // receive() external payable {}

    // function testHarvest() public {
    //     testDeposit();

    //     // Assume reward
    //     skip(864000);
    //     // deal(address(VELO), address(vaultUSDC), 1000 ether);
    //     deal(address(OP), address(vaultUSDC), 13 ether);

    //     // Harvest
    //     vaultUSDC.harvest();

    //     // Assertion check start
    //     assertEq(VELO.balanceOf(address(vaultUSDC)), 0);
    //     assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
    //     assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
    //     // console.log(aUSDC.balanceOf(address(vaultUSDC))); // 118550456 127843902
    //     assertGt(USDC.balanceOf(owner), 0); // treasury fee
    //     (,,uint lastATokenAmt, uint accRewardPerlpToken) = vaultUSDC.reward();
    //     assertGt(lastATokenAmt, 0);
    //     assertGt(accRewardPerlpToken, 0);

    //     // Assume aToken increase
    //     // aUSDC
    //     hoax(0x5F34c530Ffcc091bFb7228B20892612F79361C34);
    //     aUSDC.transfer(address(vaultUSDC), 10e6);
    //     (,,uint lastATokenAmtUSDC, uint accRewardPerlpTokenUSDC) = vaultUSDC.reward();
    //     uint userPendingvaultUSDC = vaultUSDC.getUserPendingReward(address(this));

    //     // Harvest again
    //     vaultUSDC.harvest();
    //     // Assertion check
    //     (,,lastATokenAmt, accRewardPerlpToken) = vaultUSDC.reward();
    //     assertGt(lastATokenAmt, lastATokenAmtUSDC);
    //     assertGt(accRewardPerlpToken, accRewardPerlpTokenUSDC);
    //     assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingvaultUSDC);
    //     // console.log(userPendingvaultUSDC); // 79.131304
    // }

    // function testClaim() public {
    //     testHarvest();

    //     // Record variable before claim
    //     uint userPendingRewardUSDC = vaultUSDC.getUserPendingReward(address(this));

    //     // Reset reward token balance if any
    //     deal(address(USDC), address(this), 0);

    //     // Claim
    //     vaultUSDC.claim();

    //     // Assertion check start
    //     assertEq(USDC.balanceOf(address(this)), userPendingRewardUSDC);
    //     (, uint rewardStartAt) = vaultUSDC.userInfo(address(this));
    //     assertGt(rewardStartAt, 0);
    //     (,,uint lastATokenAmt,) = vaultUSDC.reward();
    //     assertLe(lastATokenAmt, 2);
    //     assertLe(aUSDC.balanceOf(address(vaultUSDC)), 2);
    //     assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
    // }

    // function testPauseContract() public {
    //     deal(address(token0), address(this), 10 ether);
    //     token0.approve(address(vaultUSDC), type(uint).max);
    //     // // Pause contract and test deposit
    //     hoax(owner);
    //     vaultUSDC.pauseContract();
    //     vm.expectRevert(bytes("Pausable: paused"));
    //     vaultUSDC.deposit(token0, 10 ether, 500, 0);
    //     // Unpause contract and test deposit
    //     hoax(owner);
    //     vaultUSDC.unPauseContract();
    //     vaultUSDC.deposit(token0, 10 ether, 500, 0);
    //     vm.roll(block.number + 1);
    //     // Pause contract and test withdraw
    //     hoax(owner);
    //     vaultUSDC.pauseContract();
    //     vaultUSDC.withdraw(token0, vaultUSDC.getUserBalance(address(this)), 0);
    // }

    // function testUpgrade() public {
    //     PbVelo vault_ = new PbVelo();
    //     startHoax(owner);
    //     vaultUSDC.upgradeTo(address(vault_));
    // }

    // function testSetter() public {
    //     startHoax(owner);
    //     vaultUSDC.setYieldFeePerc(1000);
    //     assertEq(vaultUSDC.yieldFeePerc(), 1000);
    //     vaultUSDC.setTreasury(address(1));
    //     assertEq(vaultUSDC.treasury(), address(1));
    // }

    // function testAuthorization() public {
    //     assertEq(vaultUSDC.owner(), owner);
    //     // TransferOwnership
    //     startHoax(owner);
    //     vaultUSDC.transferOwnership(address(1));
    //     // Vault
    //     vm.expectRevert(bytes("Initializable: contract is already initialized"));
    //     vaultUSDC.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUSDC.pauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUSDC.unPauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUSDC.upgradeTo(address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUSDC.setYieldFeePerc(0);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUSDC.setTreasury(address(0));
    // }

    function getSwapPerc(address tokenIn) internal view returns (uint swapPerc) {
        (uint reserveA, uint reserveB) = IPair(address(lpToken)).getReserves();
        uint reserveABase = reserveA / 10 ** IERC20MetadataUpgradeable(address(token0)).decimals();
        uint reserveBBase = reserveB / 10 ** IERC20MetadataUpgradeable(address(token1)).decimals();
        uint k = reserveABase + reserveBBase;
        uint average = k / 2;
        if (reserveABase > reserveBBase) {
            uint diff = reserveABase - average;
            uint percDiff = diff * 1000 / k;
            if (tokenIn == address(token0)) swapPerc = 500 - percDiff;
            else swapPerc = 500 + percDiff;
            
        } else {
            uint diff = reserveBBase - average;
            uint percDiff = diff * 1000 / k;
            if (tokenIn == address(token0)) swapPerc = 500 + percDiff;
            else swapPerc = 500 - percDiff;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

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
    PbVelo vaultWBTC;
    PbVelo vaultWETH;
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    address gaugeAddr = 0x101D5e5651D7f949154258C1C7516da1eC273476;
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aUSDC;
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    // address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
    address owner = address(this);

    function setUp() public {
        PbVelo vaultImpl = new PbVelo();

        PbProxy proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                gaugeAddr, // _gauge
                address(USDC), // _rewardToken
                address(treasury), // _treasury
                0.001 ether // swapThreshold
            )
        );
        vaultUSDC = PbVelo(payable(address(proxy)));
        // vaultUSDC = PbVelo(payable(0xcba7864134e1A5326b817676ad5302A009c84d68));
        // hoax(owner);
        // vaultUSDC.upgradeTo(address(vaultImpl));

        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                gaugeAddr, // _gauge
                address(WBTC), // _rewardToken
                address(treasury), // _treasury
                0.001 ether // swapThreshold
            )
        );
        vaultWBTC = PbVelo(payable(address(proxy)));

        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                gaugeAddr, // _gauge
                address(WETH), // _rewardToken
                address(treasury), // _treasury
                0.001 ether // swapThreshold
            )
        );
        vaultWETH = PbVelo(payable(address(proxy)));

        token0 = IERC20Upgradeable(vaultUSDC.token0());
        token1 = IERC20Upgradeable(vaultUSDC.token1());
        lpToken = IERC20Upgradeable(vaultUSDC.lpToken());
        (, aUSDC,,) = vaultUSDC.reward();
        (, aWBTC,,) = vaultWBTC.reward();
        (, aWETH,,) = vaultWETH.reward();

        deal(address(USDC), treasury, 0);
        deal(address(WBTC), treasury, 0);
        deal(address(WETH), treasury, 0);
    }

    function testDeposit() public {
        // Deposit token0 for USDC reward
        uint swapPerc = getSwapPerc(address(token0));
        (uint amountOut,) = router.getAmountOut(
            10 ether * swapPerc / 1000, address(token0), address(token1));
        vaultUSDC.deposit{value: 10 ether}(token0, 10 ether, swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 0.021111462207938377
        // console.log(token1.balanceOf(address(this))); // 0

        // // as tested 19/3/2023 cannot swap seth to weth for weird reason
        // // Deposit token1 for USDC reward
        // address SETHHolder = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;
        // hoax(SETHHolder);
        // token1.transfer(address(this), 1 ether);
        // swapPerc = getSwapPerc(address(token1));
        // token1.approve(address(vaultUSDC), type(uint).max);
        // (amountOut,) = router.getAmountOut(
        //     token1.balanceOf(address(this)) * swapPerc / 1000, address(token1), address(token0));
        // vaultUSDC.deposit(token1, token1.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
        // // console.log(token0.balanceOf(address(this))); // 0.056510491632296631
        // // console.log(token1.balanceOf(address(this))); // 0

        // Deposit token0 for WBTC reward
        swapPerc = getSwapPerc(address(token0));
        (amountOut,) = router.getAmountOut(
            10 ether * swapPerc / 1000, address(token0), address(token1));
        vaultWBTC.deposit{value: 10 ether}(token0, 10 ether, swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 0
        // console.log(token1.balanceOf(address(this))); // 0.001193801101143287

        // Deposit LP for WETH reward
        deal(address(lpToken), address(this), 1 ether);
        lpToken.approve(address(vaultWETH), type(uint).max);
        vaultWETH.deposit(lpToken, lpToken.balanceOf(address(this)), 0, 0);

        // Assertion check
        assertGt(vaultUSDC.getUserBalance(address(this)), 0);
        // console.log(vaultUSDC.getUserBalance(address(this))); // 
        assertGt(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        // console.log(vaultUSDC.getUserBalanceInUSD(address(this))); // 
        assertGt(vaultUSDC.getPricePerFullShareInUSD(), 0);
        // console.log(vaultUSDC.getPricePerFullShareInUSD());
        assertGt(vaultUSDC.getAllPool(), 0);
        // console.log(vaultUSDC.getAllPool());
        assertGt(vaultUSDC.getAllPoolInUSD(), 0);
        // console.log(vaultUSDC.getAllPoolInUSD());
        assertEq(token0.balanceOf(address(vaultUSDC)), 0);
        assertEq(token1.balanceOf(address(vaultUSDC)), 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
        assertGt(vaultWBTC.getUserBalance(address(this)), 0);
        assertGt(vaultWBTC.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultWBTC.getPricePerFullShareInUSD(), 0);
        assertGt(vaultWBTC.getAllPool(), 0);
        assertGt(vaultWBTC.getAllPoolInUSD(), 0);
        assertEq(token0.balanceOf(address(vaultWBTC)), 0);
        assertEq(token1.balanceOf(address(vaultWBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultWBTC)), 0);
        assertGt(vaultWETH.getUserBalance(address(this)), 0);
        assertGt(vaultWETH.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultWETH.getPricePerFullShareInUSD(), 0);
        assertGt(vaultWETH.getAllPool(), 0);
        assertGt(vaultWETH.getAllPoolInUSD(), 0);
        assertEq(token0.balanceOf(address(vaultWETH)), 0);
        assertEq(token1.balanceOf(address(vaultWETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultWETH)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);

        // withdraw LP from USDC reward
        vaultUSDC.withdraw(lpToken, vaultUSDC.getUserBalance(address(this)), 0);

        // Withdraw token1 from WBTC reward
        uint userBalance = vaultWBTC.getUserBalance(address(this));
        (uint amount0,) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultWBTC.stable(), userBalance);
        (uint amountOut,) = router.getAmountOut(amount0, address(token0), address(token1));
        vaultWBTC.withdraw(token1, userBalance, amountOut * 95 / 100);

        // Withdraw token0 from WETH reward
        uint ethBal = address(this).balance;
        userBalance = vaultWETH.getUserBalance(address(this));
        (,uint amount1) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultWETH.stable(), userBalance);
        (amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        vaultWETH.withdraw(token0, userBalance, amountOut * 95 / 100);

        // Assertion check
        assertEq(vaultUSDC.getAllPool(), 0);
        assertEq(vaultUSDC.getAllPoolInUSD(), 0);
        assertEq(vaultUSDC.getUserBalance(address(this)), 0);
        assertEq(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        assertEq(token0.balanceOf(address(vaultUSDC)), 0);
        assertEq(token1.balanceOf(address(vaultUSDC)), 0);
        assertEq(address(vaultUSDC).balance, 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
        assertEq(vaultWBTC.getAllPool(), 0);
        assertEq(vaultWBTC.getAllPoolInUSD(), 0);
        assertEq(vaultWBTC.getUserBalance(address(this)), 0);
        assertEq(vaultWBTC.getUserBalanceInUSD(address(this)), 0);
        assertEq(token0.balanceOf(address(vaultWBTC)), 0);
        assertEq(token1.balanceOf(address(vaultWBTC)), 0);
        assertEq(address(vaultWBTC).balance, 0);
        assertEq(lpToken.balanceOf(address(vaultWBTC)), 0);
        assertEq(vaultWETH.getAllPool(), 0);
        assertEq(vaultWETH.getAllPoolInUSD(), 0);
        assertEq(vaultWETH.getUserBalance(address(this)), 0);
        assertEq(vaultWETH.getUserBalanceInUSD(address(this)), 0);
        assertEq(token0.balanceOf(address(vaultWETH)), 0);
        assertEq(token1.balanceOf(address(vaultWETH)), 0);
        assertEq(address(vaultWETH).balance, 0);
        assertEq(lpToken.balanceOf(address(vaultWETH)), 0);
        // console.log(address(this).balance - ethBal); // 2.998355416245694636
        // console.log(token1.balanceOf(address(this))); // 9.989197784590031074
        // console.log(lpToken.balanceOf(address(this))); // 3.333510795617660197
        assertGt(address(this).balance - ethBal, 0);
        assertGt(token1.balanceOf(address(this)), 0);
        assertGt(lpToken.balanceOf(address(this)), 0);
    }

    receive() external payable {}

    function testHarvest() public {
        testDeposit();

        skip(864000);
        assertGt(vaultUSDC.getPoolPendingReward(), 0);
        assertGt(vaultWBTC.getPoolPendingReward(), 0);
        assertGt(vaultWETH.getPoolPendingReward(), 0);

        // Assume reward
        deal(address(VELO), address(vaultUSDC), 100 ether);
        deal(address(OP), address(vaultUSDC), 10 ether);
        deal(address(VELO), address(vaultWBTC), 100 ether);
        deal(address(OP), address(vaultWBTC), 10 ether);
        deal(address(VELO), address(vaultWETH), 100 ether);
        deal(address(OP), address(vaultWETH), 10 ether);

        // Harvest
        vaultUSDC.harvest();
        vaultWBTC.harvest();
        vaultWETH.harvest();

        // Assertion check start
        // vaultUSDC
        assertEq(VELO.balanceOf(address(vaultUSDC)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
        // console.log(aUSDC.balanceOf(address(vaultUSDC))); // 59.594330
        assertGt(USDC.balanceOf(treasury), 0); // treasury fee
        (,,uint lastATokenAmt, uint accRewardPerlpToken) = vaultUSDC.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);
        // vaultWBTC
        assertEq(VELO.balanceOf(address(vaultWBTC)), 0);
        assertEq(USDC.balanceOf(address(vaultWBTC)), 0);
        assertGt(aWBTC.balanceOf(address(vaultWBTC)), 0);
        // console.log(aWBTC.balanceOf(address(vaultWBTC))); // 0.00210888
        assertGt(WBTC.balanceOf(treasury), 0); // treasury fee
        (,, lastATokenAmt, accRewardPerlpToken) = vaultWBTC.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);
        // vaultWETH
        assertEq(VELO.balanceOf(address(vaultWETH)), 0);
        assertEq(USDC.balanceOf(address(vaultWETH)), 0);
        assertGt(aWETH.balanceOf(address(vaultWETH)), 0);
        // console.log(aWETH.balanceOf(address(vaultWETH))); // 0.026945545237275619
        assertGt(WETH.balanceOf(treasury), 0); // treasury fee
        (,, lastATokenAmt, accRewardPerlpToken) = vaultWETH.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);

        // Assume aToken increase
        // aUSDC
        hoax(0x4ecB5300D9ec6BCA09d66bfd8Dcb532e3192dDA1);
        aUSDC.transfer(address(vaultUSDC), 10e6);
        (,,uint lastATokenAmtUSDC, uint accRewardPerlpTokenUSDC) = vaultUSDC.reward();
        uint userPendingvaultUSDC = vaultUSDC.getUserPendingReward(address(this));
        // aWBTC
        hoax(0x8eb23a3010795574eE3DD101843dC90bD63b5099);
        aWBTC.transfer(address(vaultWBTC), 0.0001e8);
        (,,uint lastATokenAmtWBTC, uint accRewardPerlpTokenWBTC) = vaultWBTC.reward();
        uint userPendingvaultWBTC = vaultWBTC.getUserPendingReward(address(this));
        // aWETH
        hoax(0x39fB69f58481458c5BdF8b141d11157937FFcF14);
        aWETH.transfer(address(vaultWETH), 0.001 ether);
        (,,uint lastATokenAmtWETH, uint accRewardPerlpTokenWETH) = vaultWETH.reward();
        uint userPendingvaultWETH = vaultWETH.getUserPendingReward(address(this));

        // Harvest again
        vaultUSDC.harvest();
        vaultWBTC.harvest();
        vaultWETH.harvest();
        // Assertion check
        (,,lastATokenAmt, accRewardPerlpToken) = vaultUSDC.reward();
        assertGt(lastATokenAmt, lastATokenAmtUSDC);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenUSDC);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingvaultUSDC);
        // console.log(userPendingvaultUSDC); // 50.095601
        (,,lastATokenAmt, accRewardPerlpToken) = vaultWBTC.reward();
        assertGt(lastATokenAmt, lastATokenAmtWBTC);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWBTC);
        assertGt(vaultWBTC.getUserPendingReward(address(this)), userPendingvaultWBTC);
        // console.log(userPendingvaultWBTC); // 0.00172956
        (,,lastATokenAmt, accRewardPerlpToken) = vaultWETH.reward();
        assertGt(lastATokenAmt, lastATokenAmtWETH);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWETH);
        assertGt(vaultWETH.getUserPendingReward(address(this)), userPendingvaultWETH);
        // console.log(userPendingvaultWETH); // 0.025130596555664305
    }

    function testClaim() public {
        testHarvest();

        // Record variable before claim
        uint userPendingRewardUSDC = vaultUSDC.getUserPendingReward(address(this));
        uint userPendingRewardWBTC = vaultWBTC.getUserPendingReward(address(this));
        uint userPendingRewardWETH = vaultWETH.getUserPendingReward(address(this));

        // Reset reward token balance if any
        deal(address(USDC), address(this), 0);
        deal(address(WBTC), address(this), 0);
        deal(address(WETH), address(this), 0);

        // Claim
        vaultUSDC.claim();
        vaultWBTC.claim();
        vaultWETH.claim();

        // Assertion check start
        // vaultUSDC
        assertEq(USDC.balanceOf(address(this)), userPendingRewardUSDC);
        (, uint rewardStartAt) = vaultUSDC.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (,,uint lastATokenAmt,) = vaultUSDC.reward();
        assertLe(lastATokenAmt, 2);
        assertLe(aUSDC.balanceOf(address(vaultUSDC)), 2);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        // vaultWBTC
        assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        (, rewardStartAt) = vaultWBTC.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (,,lastATokenAmt,) = vaultWBTC.reward();
        assertLe(lastATokenAmt, 2);
        assertLe(aWBTC.balanceOf(address(vaultWBTC)), 2);
        assertEq(WBTC.balanceOf(address(vaultWBTC)), 0);
        // vaultWETH
        assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
        (, rewardStartAt) = vaultWETH.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (,,lastATokenAmt,) = vaultWETH.reward();
        assertLe(lastATokenAmt, 2);
        assertLe(aWETH.balanceOf(address(vaultWETH)), 2);
        assertEq(WETH.balanceOf(address(vaultWETH)), 0);
    }

    function testPauseContract() public {
        deal(address(token0), address(this), 10 ether);
        token0.approve(address(vaultUSDC), type(uint).max);
        // // Pause contract and test deposit
        hoax(owner);
        vaultUSDC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultUSDC.deposit(token0, 10 ether, 500, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultUSDC.unPauseContract();
        vaultUSDC.deposit(token0, 10 ether, 500, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultUSDC.pauseContract();
        vaultUSDC.withdraw(token0, vaultUSDC.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbVelo vault_ = new PbVelo();
        startHoax(owner);
        vaultUSDC.upgradeTo(address(vault_));
    }

    function testSetter() public {
        startHoax(owner);
        vaultUSDC.setYieldFeePerc(1000);
        assertEq(vaultUSDC.yieldFeePerc(), 1000);
        vaultUSDC.setTreasury(address(1));
        assertEq(vaultUSDC.treasury(), address(1));
        vaultUSDC.setSwapThreshold(1 ether);
        assertEq(vaultUSDC.swapThreshold(), 1 ether);
    }

    function testAuthorization() public {
        assertEq(vaultUSDC.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultUSDC.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUSDC.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0),0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.setSwapThreshold(0);
    }

    function testGlobalVar() public {
        address sethAddr = 0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49;
        address lpTokenAddr = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;
        // vaultUSDC
        assertEq(address(vaultUSDC.token0()), address(WETH));
        assertEq(address(vaultUSDC.token1()), sethAddr);
        assertEq(address(vaultUSDC.lpToken()), lpTokenAddr);
        assertEq(address(vaultUSDC.gauge()), gaugeAddr);
        assertEq(vaultUSDC.stable(), true);
        assertEq(vaultUSDC.treasury(), treasury);
        assertEq(vaultUSDC.yieldFeePerc(), 50);
        (IERC20Upgradeable rewardToken, IERC20Upgradeable aToken, uint lastATokenAmt, uint accRewardPerlpToken) = vaultUSDC.reward();
        assertEq(address(rewardToken), address(USDC));
        assertEq(address(aToken), 0x625E7708f30cA75bfd92586e17077590C60eb4cD);
        assertEq(lastATokenAmt, 0);
        assertEq(accRewardPerlpToken, 0);
        (uint lpTokenBalance, uint rewardStartAt) = vaultUSDC.userInfo(address(this));
        assertEq(lpTokenBalance, 0);
        assertEq(rewardStartAt, 0);
        assertEq(vaultUSDC.swapThreshold(), 0.001 ether);
        assertEq(vaultUSDC.accRewardTokenAmt(), 0);
        // vaultWBTC
        assertEq(address(vaultWBTC.token0()), address(WETH));
        assertEq(address(vaultWBTC.token1()), sethAddr);
        assertEq(address(vaultWBTC.lpToken()), lpTokenAddr);
        assertEq(address(vaultWBTC.gauge()), gaugeAddr);
        assertEq(vaultWBTC.stable(), true);
        assertEq(vaultWBTC.treasury(), treasury);
        assertEq(vaultWBTC.yieldFeePerc(), 50);
        (rewardToken, aToken, lastATokenAmt, accRewardPerlpToken) = vaultWBTC.reward();
        assertEq(address(rewardToken), address(WBTC));
        assertEq(address(aToken), 0x078f358208685046a11C85e8ad32895DED33A249);
        assertEq(lastATokenAmt, 0);
        assertEq(accRewardPerlpToken, 0);
        (lpTokenBalance, rewardStartAt) = vaultWBTC.userInfo(address(this));
        assertEq(lpTokenBalance, 0);
        assertEq(rewardStartAt, 0);
        assertEq(vaultWBTC.swapThreshold(), 0.001 ether);
        assertEq(vaultWBTC.accRewardTokenAmt(), 0);
        // vaultWETH
        assertEq(address(vaultWETH.token0()), address(WETH));
        assertEq(address(vaultWETH.token1()), sethAddr);
        assertEq(address(vaultWETH.lpToken()), lpTokenAddr);
        assertEq(address(vaultWETH.gauge()), gaugeAddr);
        assertEq(vaultWETH.stable(), true);
        assertEq(vaultWETH.treasury(), treasury);
        assertEq(vaultWETH.yieldFeePerc(), 50);
        (rewardToken, aToken, lastATokenAmt, accRewardPerlpToken) = vaultWETH.reward();
        assertEq(address(rewardToken), address(WETH));
        assertEq(address(aToken), 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
        assertEq(lastATokenAmt, 0);
        assertEq(accRewardPerlpToken, 0);
        (lpTokenBalance, rewardStartAt) = vaultWETH.userInfo(address(this));
        assertEq(lpTokenBalance, 0);
        assertEq(rewardStartAt, 0);
        assertEq(vaultWETH.swapThreshold(), 0.001 ether);
        assertEq(vaultWETH.accRewardTokenAmt(), 0);
    }

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

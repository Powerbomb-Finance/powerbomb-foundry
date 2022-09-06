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

contract OPUSDCTest is Test {
    PbVelo vaultBTC;
    PbVelo vaultETH;
    PbVelo vaultUSDC;
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    IERC20Upgradeable aUSDC;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    // address owner = address(this);

    function setUp() public {
        // PbVelo vaultImpl = new PbVelo();

        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0x0299d40E99F2a5a1390261f5A71d13C3932E214C, // _gauge
        //         address(WBTC), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultBTC = PbVelo(payable(address(proxy)));
        vaultBTC = PbVelo(payable(0x2510E5054eeEbED40C3C580ae3241F5457b630D9));

        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0x0299d40E99F2a5a1390261f5A71d13C3932E214C, // _gauge
        //         address(WETH), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultETH = PbVelo(payable(address(proxy)));
        vaultETH = PbVelo(payable(0xFAcB839BF8f09f2e7B4b6C83349B5bbFD62fd659));

        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0x0299d40E99F2a5a1390261f5A71d13C3932E214C, // _gauge
        //         address(USDC), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultUSDC = PbVelo(payable(address(proxy)));
        vaultUSDC = PbVelo(payable(0x176CC5Ff9BDBf4daFB955003E6f8229f47Ef1E55));

        token0 = IERC20Upgradeable(vaultBTC.token0());
        token1 = IERC20Upgradeable(vaultBTC.token1());
        lpToken = IERC20Upgradeable(vaultBTC.lpToken());
        (, aWBTC,,) = vaultBTC.reward();
        (, aWETH,,) = vaultETH.reward();
        (, aUSDC,,) = vaultUSDC.reward();

        deal(address(WBTC), address(owner), 0);
        deal(address(WETH), address(owner), 0);
        deal(address(USDC), address(owner), 0);
    }

    function testDeposit() public {
        // Deposit token0 for BTC reward
        deal(address(token0), address(this), 10_000 ether);
        uint swapPerc = getSwapPerc(address(token0));
        token0.approve(address(vaultBTC), type(uint).max);
        (uint amountOut,) = router.getAmountOut(
            token0.balanceOf(address(this)) * swapPerc / 1000, address(token0), address(token1));
        vaultBTC.deposit(token0, token0.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 0
        // console.log(token1.balanceOf(address(this))); // 10.776111

        // Deposit token1 for ETH reward
        deal(address(token1), address(this), 10_000e6);
        swapPerc = getSwapPerc(address(token1));
        token1.approve(address(vaultETH), type(uint).max);
        (amountOut,) = router.getAmountOut(
            token1.balanceOf(address(this)) * swapPerc / 1000, address(token1), address(token0));
        vaultETH.deposit(token1, token1.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 2.843218379685929176
        // console.log(token1.balanceOf(address(this))); // 0

        // Deposit LP for usdc reward
        deal(address(lpToken), address(this), 0.001 ether);
        lpToken.approve(address(vaultUSDC), type(uint).max);
        vaultUSDC.deposit(lpToken, lpToken.balanceOf(address(this)), 0, 0);

        // Assertion check
        assertGt(vaultBTC.getUserBalance(address(this)), 0);
        assertGt(vaultETH.getUserBalance(address(this)), 0);
        assertGt(vaultUSDC.getUserBalance(address(this)), 0);
        // console.log(vaultBTC.getUserBalance(address(this))); // 0.006158803230507752
        // console.log(vaultETH.getUserBalance(address(this))); // 0.004054909088572045
        // console.log(vaultUSDC.getUserBalance(address(this))); // 0.001000000000000000
        assertGt(vaultBTC.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultETH.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        // console.log(vaultBTC.getUserBalanceInUSD(address(this))); // 15266.998770
        // console.log(vaultETH.getUserBalanceInUSD(address(this))); // 10051.675585
        // console.log(vaultUSDC.getUserBalanceInUSD(address(this))); // 2478.890492
        assertGt(vaultBTC.getPricePerFullShareInUSD(), 0);
        assertGt(vaultETH.getPricePerFullShareInUSD(), 0);
        assertGt(vaultUSDC.getPricePerFullShareInUSD(), 0);
        // console.log(vaultBTC.getPricePerFullShareInUSD());
        // console.log(vaultETH.getPricePerFullShareInUSD());
        // console.log(vaultUSDC.getPricePerFullShareInUSD());
        assertGt(vaultBTC.getAllPool(), 0);
        assertGt(vaultETH.getAllPool(), 0);
        assertGt(vaultUSDC.getAllPool(), 0);
        // console.log(vaultBTC.getAllPool());
        // console.log(vaultETH.getAllPool());
        // console.log(vaultUSDC.getAllPool());
        assertGt(vaultBTC.getAllPoolInUSD(), 0);
        assertGt(vaultETH.getAllPoolInUSD(), 0);
        assertGt(vaultUSDC.getAllPoolInUSD(), 0);
        // console.log(vaultBTC.getAllPoolInUSD());
        // console.log(vaultETH.getAllPoolInUSD());
        // console.log(vaultUSDC.getAllPoolInUSD());
        assertEq(token0.balanceOf(address(vaultBTC)), 0);
        assertEq(token1.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(token0.balanceOf(address(vaultETH)), 0);
        assertEq(token1.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
        assertEq(token0.balanceOf(address(vaultUSDC)), 0);
        assertEq(token1.balanceOf(address(vaultUSDC)), 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);

        // withdraw LP from USDC reward
        vaultUSDC.withdraw(lpToken, 0.001 ether, 0);
        assertEq(lpToken.balanceOf(address(this)), 0.001 ether);

        // Withdraw token1 from BTC reward
        uint userBalance = vaultBTC.getUserBalance(address(this));
        (uint amount0,) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultBTC.stable(), userBalance);
        (uint amountOut,) = router.getAmountOut(amount0, address(token0), address(token1));
        vaultBTC.withdraw(token1, userBalance, amountOut * 95 / 100);

        // Withdraw token0 from ETH reward
        userBalance = vaultETH.getUserBalance(address(this));
        (,uint amount1) = router.quoteRemoveLiquidity(address(token0), address(token1), vaultETH.stable(), userBalance);
        (amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        vaultETH.withdraw(token0, userBalance, amountOut * 95 / 100);

        // Assertion check
        assertEq(vaultBTC.getAllPool(), 0);
        assertEq(vaultBTC.getAllPoolInUSD(), 0);
        assertEq(vaultBTC.getUserBalance(address(this)), 0);
        assertEq(vaultBTC.getUserBalanceInUSD(address(this)), 0);
        assertEq(vaultETH.getAllPool(), 0);
        assertEq(vaultETH.getAllPoolInUSD(), 0);
        assertEq(vaultETH.getUserBalance(address(this)), 0);
        assertEq(vaultETH.getUserBalanceInUSD(address(this)), 0);
        assertEq(vaultUSDC.getAllPool(), 0);
        assertEq(vaultUSDC.getAllPoolInUSD(), 0);
        assertEq(vaultUSDC.getUserBalance(address(this)), 0);
        assertEq(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this))); // 0.001000000000000000
        // console.log(token0.balanceOf(address(this))); // 6586.231624663510749663
        // console.log(token1.balanceOf(address(this))); // 15174.738761
        assertEq(token0.balanceOf(address(vaultBTC)), 0);
        assertEq(token1.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(token0.balanceOf(address(vaultETH)), 0);
        assertEq(token1.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
        assertEq(token0.balanceOf(address(vaultUSDC)), 0);
        assertEq(token1.balanceOf(address(vaultUSDC)), 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
        assertGt(token0.balanceOf(address(this)), 0);
        assertGt(token1.balanceOf(address(this)), 0);
        assertGt(lpToken.balanceOf(address(this)), 0);
    }

    function testHarvest() public {
        testDeposit();

        // Assume reward
        skip(864000);
        // deal(address(VELO), address(vaultBTC), 1000 ether);
        // deal(address(VELO), address(vaultETH), 1000 ether);
        // deal(address(VELO), address(vaultUSDC), 1000 ether);
        deal(address(OP), address(vaultBTC), 13 ether);
        deal(address(OP), address(vaultETH), 13 ether);
        deal(address(OP), address(vaultUSDC), 13 ether);

        // Harvest
        vaultBTC.harvest();
        vaultETH.harvest();
        vaultUSDC.harvest();

        // Assertion check start
        assertEq(VELO.balanceOf(address(vaultBTC)), 0);
        assertEq(VELO.balanceOf(address(vaultETH)), 0);
        assertEq(VELO.balanceOf(address(vaultUSDC)), 0);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertGt(aWBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertGt(aWETH.balanceOf(address(vaultETH)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(WBTC.balanceOf(owner), 0); // treasury fee
        assertGt(WETH.balanceOf(owner), 0); // treasury fee
        assertGt(USDC.balanceOf(owner), 0); // treasury fee
        (,,uint lastATokenAmt, uint accRewardPerlpToken) = vaultBTC.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultETH.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultUSDC.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);

        // Assume aToken increase
        // aWBTC
        hoax(0xc4f24fa48D6DF95097b2577caC2cAf186bC92a00);
        aWBTC.transfer(address(vaultBTC), 1e5);
        (,,uint lastATokenAmtWBTC, uint accRewardPerlpTokenWBTC) = vaultBTC.reward();
        uint userPendingVaultBTC = vaultBTC.getUserPendingReward(address(this));
        // aWETH
        hoax(0x9CBF099ff424979439dFBa03F00B5961784c06ce);
        aWETH.transfer(address(vaultETH), 1e16);
        (,,uint lastATokenAmtWETH, uint accRewardPerlpTokenWETH) = vaultBTC.reward();
        uint userPendingVaultETH = vaultETH.getUserPendingReward(address(this));
        // aUSDC
        hoax(0x5F34c530Ffcc091bFb7228B20892612F79361C34);
        aUSDC.transfer(address(vaultUSDC), 10e6);
        (,,uint lastATokenAmtUSDC, uint accRewardPerlpTokenUSDC) = vaultUSDC.reward();
        uint userPendingVaultUSDC = vaultUSDC.getUserPendingReward(address(this));

        // Harvest again
        vaultBTC.harvest();
        vaultETH.harvest();
        vaultUSDC.harvest();
        // Assertion check
        (,,lastATokenAmt, accRewardPerlpToken) = vaultBTC.reward();
        assertGt(lastATokenAmt, lastATokenAmtWBTC);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWBTC);
        assertGt(vaultBTC.getUserPendingReward(address(this)), userPendingVaultBTC);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultETH.reward();
        assertGt(lastATokenAmt, lastATokenAmtWETH);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWETH);
        assertGt(vaultETH.getUserPendingReward(address(this)), userPendingVaultETH);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultUSDC.reward();
        assertGt(lastATokenAmt, lastATokenAmtUSDC);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenUSDC);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingVaultUSDC);
        // console.log(userPendingVaultBTC); // 332924 -> 79.47 USD
        // console.log(userPendingVaultETH); // 46286086885960949 -> 79.68 USD
        // console.log(userPendingVaultUSDC); // 78.436453
    }

    function testClaim() public {
        testHarvest();

        // Record variable before claim
        uint userPendingRewardWBTC = vaultBTC.getUserPendingReward(address(this));
        uint userPendingRewardWETH = vaultETH.getUserPendingReward(address(this));
        uint userPendingRewardUSDC = vaultUSDC.getUserPendingReward(address(this));

        // Reset reward token balance if any
        deal(address(WBTC), address(this), 0);
        deal(address(WETH), address(this), 0);
        deal(address(USDC), address(this), 0);

        // Claim
        vaultBTC.claim();
        vaultETH.claim();
        vaultUSDC.claim();

        // Assertion check start
        assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
        assertEq(USDC.balanceOf(address(this)), userPendingRewardUSDC);
        (, uint rewardStartAt) = vaultBTC.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (, rewardStartAt) = vaultETH.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (, rewardStartAt) = vaultUSDC.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (,,uint lastATokenAmt,) = vaultBTC.reward();
        assertLe(lastATokenAmt, 2);
        (,,lastATokenAmt,) = vaultETH.reward();
        assertLe(lastATokenAmt, 2);
        (,,lastATokenAmt,) = vaultUSDC.reward();
        assertLe(lastATokenAmt, 2);
        assertLe(aWBTC.balanceOf(address(vaultBTC)), 2);
        assertLe(aWETH.balanceOf(address(vaultETH)), 2);
        assertLe(aUSDC.balanceOf(address(vaultUSDC)), 2);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
    }

    function testPauseContract() public {
        deal(address(token0), address(this), 10_000 ether);
        token0.approve(address(vaultBTC), type(uint).max);
        // // Pause contract and test deposit
        hoax(owner);
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultBTC.deposit(token0, 10_000 ether, 500, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultBTC.unPauseContract();
        vaultBTC.deposit(token0, 10_000 ether, 500, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultBTC.pauseContract();
        vaultBTC.withdraw(token0, vaultBTC.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbVelo vault_ = new PbVelo();
        startHoax(owner);
        vaultBTC.upgradeTo(address(vault_));
        vaultETH.upgradeTo(address(vault_));
        vaultUSDC.upgradeTo(address(vault_));
    }

    function testSetter() public {
        startHoax(owner);
        vaultBTC.setYieldFeePerc(1000);
        assertEq(vaultBTC.yieldFeePerc(), 1000);
        vaultBTC.setTreasury(address(1));
        assertEq(vaultBTC.treasury(), address(1));
        vaultETH.setYieldFeePerc(1000);
        assertEq(vaultETH.yieldFeePerc(), 1000);
        vaultETH.setTreasury(address(1));
        assertEq(vaultETH.treasury(), address(1));
        vaultUSDC.setYieldFeePerc(1000);
        assertEq(vaultUSDC.yieldFeePerc(), 1000);
        vaultUSDC.setTreasury(address(1));
        assertEq(vaultUSDC.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultBTC.owner(), owner);
        assertEq(vaultETH.owner(), owner);
        assertEq(vaultUSDC.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultBTC.transferOwnership(address(1));
        vaultETH.transferOwnership(address(1));
        vaultUSDC.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultBTC.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultETH.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUSDC.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDC.setTreasury(address(0));
    }

    function getSwapPerc(address tokenIn) internal view returns (uint swapPerc) {
        if (IPair(address(lpToken)).stable()) {
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
        } else {
            swapPerc = 500;
        }
    }
}

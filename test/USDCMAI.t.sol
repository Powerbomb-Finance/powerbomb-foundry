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

contract USDCMAITest is Test {
    PbVelo vaultBTC;
    PbVelo vaultETH;
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWBTC;
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
        //         0xDF479E13E71ce207CE1e58D6f342c039c3D90b7D, // _gauge
        //         address(WBTC), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultBTC = PbVelo(payable(address(proxy)));
        vaultBTC = PbVelo(payable(0x52671440732589E3027517E22c49ABc04941CF2F));
        // hoax(owner);
        // vaultBTC.upgradeTo(address(vaultImpl));

        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0xDF479E13E71ce207CE1e58D6f342c039c3D90b7D, // _gauge
        //         address(WETH), // _rewardToken
        //         address(owner) // _treasury
        //     )
        // );
        // vaultETH = PbVelo(payable(address(proxy)));
        vaultETH = PbVelo(payable(0x3BD8d78d77dfA391c5F73c10aDeaAdD9a7f7198C));
        // hoax(owner);
        // vaultETH.upgradeTo(address(vaultImpl));

        // vm.startPrank(owner);
        // vaultBTC.setSwapThreshold(0.001 ether);
        // vaultETH.setSwapThreshold(0.001 ether);
        // vm.stopPrank();

        token0 = IERC20Upgradeable(vaultBTC.token0());
        token1 = IERC20Upgradeable(vaultBTC.token1());
        lpToken = IERC20Upgradeable(vaultBTC.lpToken());
        (, aWBTC,,) = vaultBTC.reward();
        (, aWETH,,) = vaultETH.reward();
    }

    // function test() public {
    //     IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    //     deal(address(usdc), address(this), 100000e6);
    //     usdc.approve(address(vaultETH), type(uint).max);
    //     vaultETH.deposit(usdc, 100000e6, getSwapPerc(address(usdc)), 0);
    //     // console.log(vaultETH.getUserBalanceInUSD(address(this)));
    //     console.log(token0.balanceOf(address(this))); // 208.626335
    //     console.log(token1.balanceOf(address(this))); // 1
    //     // console.log(lpToken.balanceOf(address(this)));
    // }

    function testDeposit() public {
        // Deposit token0 for BTC reward
        deal(address(token0), address(this), 10_000e6);
        uint swapPerc = getSwapPerc(address(token0));
        token0.approve(address(vaultBTC), type(uint).max);
        (uint amountOut,) = router.getAmountOut(
            token0.balanceOf(address(this)) * swapPerc / 1000, address(token0), address(token1));
        vaultBTC.deposit(token0, token0.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 0
        // console.log(token1.balanceOf(address(this))); // 6.014957625246692934

        // Deposit token1 for ETH reward
        deal(address(token1), address(this), 10_000 ether);
        swapPerc = getSwapPerc(address(token1));
        token1.approve(address(vaultETH), type(uint).max);
        (amountOut,) = router.getAmountOut(
            token1.balanceOf(address(this)) * swapPerc / 1000, address(token1), address(token0));
        vaultETH.deposit(token1, token1.balanceOf(address(this)), swapPerc, amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this))); // 24.591251
        // console.log(token1.balanceOf(address(this))); // 0

        // Deposit LP for BTC reward
        deal(address(lpToken), address(this), 0.0001 ether);
        lpToken.approve(address(vaultBTC), type(uint).max);
        vaultBTC.deposit(lpToken, lpToken.balanceOf(address(this)), 0, 0);

        // Assertion check
        assertGt(vaultBTC.getUserBalance(address(this)), 0);
        assertGt(vaultETH.getUserBalance(address(this)), 0);
        // console.log(vaultBTC.getUserBalance(address(this))); // 0.005088905044034681
        // console.log(vaultETH.getUserBalance(address(this))); // 0.004990687230383350
        assertGt(vaultBTC.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultETH.getUserBalanceInUSD(address(this)), 0);
        // console.log(vaultBTC.getUserBalanceInUSD(address(this)));
        // console.log(vaultETH.getUserBalanceInUSD(address(this)));
        assertGt(vaultBTC.getPricePerFullShareInUSD(), 0);
        assertGt(vaultETH.getPricePerFullShareInUSD(), 0);
        // console.log(vaultBTC.getPricePerFullShareInUSD());
        // console.log(vaultETH.getPricePerFullShareInUSD());
        assertGt(vaultBTC.getAllPool(), 0);
        assertGt(vaultETH.getAllPool(), 0);
        // console.log(vaultBTC.getAllPool());
        // console.log(vaultETH.getAllPool());
        assertGt(vaultBTC.getAllPoolInUSD(), 0);
        assertGt(vaultETH.getAllPoolInUSD(), 0);
        // console.log(vaultBTC.getAllPoolInUSD()); // 10146.139463
        // console.log(vaultETH.getAllPoolInUSD()); // 9950.315091
        assertEq(token0.balanceOf(address(vaultBTC)), 0);
        assertEq(token1.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(token0.balanceOf(address(vaultETH)), 0);
        assertEq(token1.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);

        // withdraw LP from ETH reward
        vaultETH.withdraw(lpToken, 0.0001 ether, 0);
        assertEq(lpToken.balanceOf(address(this)), 0.0001 ether);

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
        // assertEq(vaultBTC.getAllPool(), 0);
        // assertEq(vaultBTC.getAllPoolInUSD(), 0);
        assertEq(vaultBTC.getUserBalance(address(this)), 0);
        assertEq(vaultBTC.getUserBalanceInUSD(address(this)), 0);
        // assertEq(vaultETH.getAllPool(), 0);
        // assertEq(vaultETH.getAllPoolInUSD(), 0);
        assertEq(vaultETH.getUserBalance(address(this)), 0);
        assertEq(vaultETH.getUserBalanceInUSD(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this))); // 0.000100000000000000
        // console.log(token0.balanceOf(address(this))); // 9824.835166
        // console.log(token1.balanceOf(address(this))); // 10171.201936729782409213
        assertEq(token0.balanceOf(address(vaultBTC)), 0);
        assertEq(token1.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(token0.balanceOf(address(vaultETH)), 0);
        assertEq(token1.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
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
        deal(address(OP), address(vaultBTC), 13 ether);
        deal(address(OP), address(vaultETH), 13 ether);

        // Harvest
        vaultBTC.harvest();
        vaultETH.harvest();

        // Assertion check start
        assertEq(VELO.balanceOf(address(vaultBTC)), 0);
        assertEq(VELO.balanceOf(address(vaultETH)), 0);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertGt(aWBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertGt(aWETH.balanceOf(address(vaultETH)), 0);
        assertGt(WBTC.balanceOf(owner), 0); // treasury fee
        assertGt(WETH.balanceOf(owner), 0); // treasury fee
        (,,uint lastATokenAmt, uint accRewardPerlpToken) = vaultBTC.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultETH.reward();
        assertGt(lastATokenAmt, 0);
        assertGt(accRewardPerlpToken, 0);

        // Assume aToken increase
        // aWBTC
        hoax(0xc4f24fa48D6DF95097b2577caC2cAf186bC92a00);
        aWBTC.transfer(address(vaultBTC), 1e5);
        (,,uint lastATokenAmtWBTC, uint accRewardPerlpTokenWBTC) = vaultBTC.reward();
        uint userPendingVaultBTC = vaultBTC.getUserPendingReward(address(this));
        // aWETH
        hoax(0xa3fDC58439b4677A11b9b0C49caE0fCA9c23Ab8a);
        aWETH.transfer(address(vaultETH), 1e16);
        (,,uint lastATokenAmtWETH, uint accRewardPerlpTokenWETH) = vaultBTC.reward();
        uint userPendingVaultETH = vaultETH.getUserPendingReward(address(this));

        // Harvest again
        vaultBTC.harvest();
        vaultETH.harvest();
        // Assertion check
        (,,lastATokenAmt, accRewardPerlpToken) = vaultBTC.reward();
        assertGt(lastATokenAmt, lastATokenAmtWBTC);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWBTC);
        assertGt(vaultBTC.getUserPendingReward(address(this)), userPendingVaultBTC);
        (,,lastATokenAmt, accRewardPerlpToken) = vaultETH.reward();
        assertGt(lastATokenAmt, lastATokenAmtWETH);
        assertGt(accRewardPerlpToken, accRewardPerlpTokenWETH);
        assertGt(vaultETH.getUserPendingReward(address(this)), userPendingVaultETH);
        // console.log(userPendingVaultBTC); // 332924 -> 79.47 USD
        // console.log(userPendingVaultETH); // 46286086885960949 -> 79.68 USD
    }

    function testClaim() public {
        testHarvest();

        // Record variable before claim
        uint userPendingRewardWBTC = vaultBTC.getUserPendingReward(address(this));
        uint userPendingRewardWETH = vaultETH.getUserPendingReward(address(this));

        // Reset reward token balance if any
        deal(address(WBTC), address(this), 0);
        deal(address(WETH), address(this), 0);

        // Claim
        vaultBTC.claim();
        vaultETH.claim();

        // Assertion check start
        assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
        (, uint rewardStartAt) = vaultBTC.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        (, rewardStartAt) = vaultETH.userInfo(address(this));
        assertGt(rewardStartAt, 0);
        // (,,uint lastATokenAmt,) = vaultBTC.reward();
        // assertLe(lastATokenAmt, 2);
        // (,,lastATokenAmt,) = vaultETH.reward();
        // assertLe(lastATokenAmt, 2);
        // assertLe(aWBTC.balanceOf(address(vaultBTC)), 2);
        // assertLe(aWETH.balanceOf(address(vaultETH)), 2);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
    }

    function testPauseContract() public {
        deal(address(token0), address(this), 10000e6);
        token0.approve(address(vaultBTC), type(uint).max);
        // // Pause contract and test deposit
        hoax(owner);
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultBTC.deposit(token0, 10000e6, 500, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultBTC.unPauseContract();
        vaultBTC.deposit(token0, 10000e6, 500, 0);
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
    }

    function testSetter() public {
        startHoax(owner);
        vaultBTC.setYieldFeePerc(1000);
        assertEq(vaultBTC.yieldFeePerc(), 1000);
        vaultBTC.setTreasury(address(1));
        assertEq(vaultBTC.treasury(), address(1));
        vaultBTC.setSwapThreshold(1 ether);
        assertEq(vaultBTC.swapThreshold(), 1 ether);
        vaultETH.setYieldFeePerc(1000);
        assertEq(vaultETH.yieldFeePerc(), 1000);
        vaultETH.setTreasury(address(1));
        assertEq(vaultETH.treasury(), address(1));
        vaultETH.setSwapThreshold(1 ether);
        assertEq(vaultETH.swapThreshold(), 1 ether);
    }

    function testAuthorization() public {
        assertEq(vaultBTC.owner(), owner);
        assertEq(vaultETH.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultBTC.transferOwnership(address(1));
        vaultETH.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultBTC.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultETH.initialize(IGauge(address(0)), IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setSwapThreshold(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setSwapThreshold(0);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PbCrvPolyTri.sol";
import "../src/PbProxy.sol";

contract PbCrvPolyTriTest is Test {
    IPool pool = IPool(0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8);
    IGauge gauge = IGauge(0xBb1B19495B8FE7C402427479B9aC14886cbbaaeE);
    IERC20Upgradeable CRV = IERC20Upgradeable(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    IERC20Upgradeable DAI = IERC20Upgradeable(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20Upgradeable USDT = IERC20Upgradeable(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    PbCrvPolyTri vaultBTC;
    PbCrvPolyTri vaultETH;
    PbCrvPolyTri vaultUSDC;
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    IERC20Upgradeable aUSDC;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // // Deploy implementation contract
        // PbCrvPolyTri vaultImpl = new PbCrvPolyTri();
        // // Deploy BTC reward proxy contract
        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(WBTC),
        //         address(6288)
        //     )
        // );
        // vaultBTC = PbCrvPolyTri(address(proxy));
        vaultBTC = PbCrvPolyTri(address(0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab));
        // // Deploy ETH reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(WETH),
        //         address(6288)
        //     )
        // );
        // vaultETH = PbCrvPolyTri(address(proxy));
        vaultETH = PbCrvPolyTri(address(0x5abbEB3323D4B19C4C371C9B056390239FC0Bf43));
        // // Deploy USDC reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(USDC),
        //         address(6288)
        //     )
        // );
        // vaultUSDC = PbCrvPolyTri(address(proxy));
        vaultUSDC = PbCrvPolyTri(address(0x7331f946809406F455623d0e69612151655e8261));
        // Initialize aToken
        aWBTC = IERC20Upgradeable(vaultBTC.aToken());
        aWETH = IERC20Upgradeable(vaultETH.aToken());
        aUSDC = IERC20Upgradeable(vaultUSDC.aToken());
    }

    function testDeposit() public {
        // Deposit DAI for BTC reward
        deal(address(DAI), address(this), 10000 ether);
        DAI.approve(address(vaultBTC), type(uint).max);
        uint[5] memory amounts = [DAI.balanceOf(address(this)), 0, 0, 0, 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultBTC.deposit(DAI, DAI.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit USDC for ETH reward
        deal(address(USDC), address(this), 10000e6);
        USDC.approve(address(vaultETH), type(uint).max);
        amounts = [0, USDC.balanceOf(address(this)), 0, 0, 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultETH.deposit(USDC, USDC.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit USDT for USDT reward
        deal(address(USDT), address(this), 10000e6);
        USDT.approve(address(vaultUSDC), type(uint).max);
        amounts = [0, 0, USDT.balanceOf(address(this)), 0, 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultUSDC.deposit(USDT, USDT.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit WBTC for WBTC reward
        deal(address(WBTC), address(this), 1e8);
        WBTC.approve(address(vaultBTC), type(uint).max);
        amounts = [0, 0, 0, WBTC.balanceOf(address(this)), 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultBTC.deposit(WBTC, WBTC.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit WETH for ETH reward
        deal(address(WETH), address(this), 10 ether);
        WETH.approve(address(vaultETH), type(uint).max);
        amounts = [0, 0, 0, 0, WETH.balanceOf(address(this))];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultETH.deposit(WETH, WETH.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit lpToken for USDC reward
        deal(address(lpToken), address(this), 1 ether);
        lpToken.approve(address(vaultUSDC), type(uint).max);
        vaultUSDC.deposit(lpToken, lpToken.balanceOf(address(this)), 0);
        // Assertion check
        assertGt(vaultBTC.getAllPool(), 0);
        assertGt(vaultETH.getAllPool(), 0);
        assertGt(vaultUSDC.getAllPool(), 0);
        uint balWBTC = vaultBTC.getUserBalance(address(this));
        uint balWETH = vaultETH.getUserBalance(address(this));
        uint balUSDC = vaultUSDC.getUserBalance(address(this));
        assertGt(balWBTC, 0);
        assertGt(balWETH, 0);
        assertGt(balUSDC, 0);
        uint balWBTC_USD = vaultBTC.getUserBalanceInUSD(address(this));
        uint balWETH_USD = vaultETH.getUserBalanceInUSD(address(this));
        uint balUSDC_USD = vaultUSDC.getUserBalanceInUSD(address(this));
        // console.log(balWBTC_USD);
        // console.log(balWETH_USD);
        // console.log(balUSDC_USD);
        assertGt(balWBTC_USD, 0);
        assertGt(balWETH_USD, 0);
        assertGt(balUSDC_USD, 0);
        assertEq(DAI.balanceOf(address(vaultBTC)), 0);
        assertEq(USDC.balanceOf(address(vaultETH)), 0);
        assertEq(USDT.balanceOf(address(vaultUSDC)), 0);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint halfUserBalBTC = vaultBTC.getUserBalance(address(this)) / 2;
        uint halfUserBalETH = vaultETH.getUserBalance(address(this)) / 2;
        uint halfUserBalUSDC = vaultUSDC.getUserBalance(address(this)) / 2;
        // Withdraw DAI from WBTC reward
        uint amountOut = pool.calc_withdraw_one_coin(halfUserBalBTC, uint(0));
        vaultBTC.withdraw(DAI, halfUserBalBTC, amountOut * 99 / 100);
        // console.log(DAI.balanceOf(address(this))); // 15138.671720640953851549
        // Withdraw USDC from WETH reward
        amountOut = pool.calc_withdraw_one_coin(halfUserBalETH, uint(1));
        vaultETH.withdraw(USDC, halfUserBalETH, amountOut * 99 / 100);
        // console.log(USDC.balanceOf(address(this))); // 10392.934151
        // Withdraw USDT from USDC reward
        amountOut = pool.calc_withdraw_one_coin(halfUserBalUSDC, uint(2));
        vaultUSDC.withdraw(USDT, halfUserBalUSDC, amountOut * 99 / 100);
        // console.log(USDT.balanceOf(address(this))); // 5416.620462
        // Withdraw WBTC from WBTC reward
        amountOut = pool.calc_withdraw_one_coin(halfUserBalBTC, uint(3));
        vaultBTC.withdraw(WBTC, halfUserBalBTC, amountOut * 99 / 100);
        // console.log(WBTC.balanceOf(address(this))); // 0.74551177
        // Withdraw WETH from WETH reward
        amountOut = pool.calc_withdraw_one_coin(halfUserBalETH, uint(4));
        vaultETH.withdraw(WETH, halfUserBalETH, amountOut * 99 / 100);
        // console.log(WETH.balanceOf(address(this))); // 9.612289812386781347
        // Withdraw lpToken from USDC reward
        vaultUSDC.withdraw(lpToken, halfUserBalUSDC, 0);
        // console.log(lpToken.balanceOf(address(this))); // 6.228781800066103271
        // Assertion check
        assertLe(vaultBTC.getAllPool(), 1);
        assertLe(vaultBTC.getAllPoolInUSD(), 1);
        assertLe(vaultBTC.getUserBalance(address(this)), 1);
        assertLe(vaultBTC.getUserBalanceInUSD(address(this)), 1);
        assertLe(vaultETH.getAllPool(), 1);
        assertLe(vaultETH.getAllPoolInUSD(), 1);
        assertLe(vaultETH.getUserBalance(address(this)), 1);
        assertLe(vaultETH.getUserBalanceInUSD(address(this)), 1);
        assertLe(vaultUSDC.getAllPool(), 1);
        assertLe(vaultUSDC.getAllPoolInUSD(), 1);
        assertLe(vaultUSDC.getUserBalance(address(this)), 1);
        assertLe(vaultUSDC.getUserBalanceInUSD(address(this)), 1);
    }

    function testHarvest() public {
        testDeposit();
        // Assume reward
        skip(864000);
        assertGt(gauge.claimable_tokens(address(vaultBTC)), 0);
        assertGt(gauge.claimable_tokens(address(vaultETH)), 0);
        assertGt(gauge.claimable_tokens(address(vaultUSDC)), 0);
        // Harvest BTC reward
        vaultBTC.harvest();
        // Harvest ETH reward
        vaultETH.harvest();
        // Harvest USDC reward
        vaultUSDC.harvest();
        // Assertion check
        assertGt(vaultBTC.getUserPendingReward(address(this)), 0);
        assertGt(vaultETH.getUserPendingReward(address(this)), 0);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), 0);
        assertEq(CRV.balanceOf(address(vaultBTC)), 0);
        assertEq(CRV.balanceOf(address(vaultETH)), 0);
        assertEq(CRV.balanceOf(address(vaultUSDC)), 0);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertGt(aWBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertGt(aWETH.balanceOf(address(vaultETH)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(WBTC.balanceOf(owner), 0); // treasury fee
        assertGt(WETH.balanceOf(owner), 0); // treasury fee
        assertGt(USDC.balanceOf(owner), 0); // treasury fee
        assertGt(vaultBTC.accRewardPerlpToken(), 0);
        assertGt(vaultETH.accRewardPerlpToken(), 0);
        assertGt(vaultUSDC.accRewardPerlpToken(), 0);
        assertGt(vaultBTC.lastATokenAmt(), 0);
        assertGt(vaultETH.lastATokenAmt(), 0);
        assertGt(vaultUSDC.lastATokenAmt(), 0);
        assertEq(gauge.claimable_tokens(address(vaultBTC)), 0);
        assertEq(gauge.claimable_tokens(address(vaultETH)), 0);
        assertEq(gauge.claimable_tokens(address(vaultUSDC)), 0);
        // Assume aToken increase
        // aWBTC
        hoax(0x6B45B74295ed34948Df617dA9ab360Cb6CAd4045);
        aWBTC.transfer(address(vaultBTC), 1e5);
        uint accRewardPerlpTokenWBTC = vaultBTC.accRewardPerlpToken();
        uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
        uint userPendingVaultBTC = vaultBTC.getUserPendingReward(address(this));
        // aWETH
        hoax(0x417afF82D2cd9fD39fE790Af5798ae865fbe8C48);
        aWETH.transfer(address(vaultETH), 1e16);
        uint accRewardPerlpTokenWETH = vaultETH.accRewardPerlpToken();
        uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
        uint userPendingVaultETH = vaultETH.getUserPendingReward(address(this));
        // aUSDC
        hoax(0xF84De0A5bE00e84a53900B1aeB8054f27A3bD560);
        aUSDC.transfer(address(vaultUSDC), 10e6);
        uint accRewardPerlpTokenUSDC = vaultUSDC.accRewardPerlpToken();
        uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        uint userPendingVaultUSDC = vaultUSDC.getUserPendingReward(address(this));
        // Harvest again
        vaultBTC.harvest();
        vaultETH.harvest();
        vaultUSDC.harvest();
        // Assertion check
        assertGt(vaultBTC.accRewardPerlpToken(), accRewardPerlpTokenWBTC);
        assertGt(vaultBTC.lastATokenAmt(), lastATokenAmtWBTC);
        assertGt(vaultBTC.getUserPendingReward(address(this)), userPendingVaultBTC);
        assertGt(vaultETH.accRewardPerlpToken(), accRewardPerlpTokenWETH);
        assertGt(vaultETH.lastATokenAmt(), lastATokenAmtWETH);
        assertGt(vaultETH.getUserPendingReward(address(this)), userPendingVaultETH);
        assertGt(vaultUSDC.accRewardPerlpToken(), accRewardPerlpTokenUSDC);
        assertGt(vaultUSDC.lastATokenAmt(), lastATokenAmtUSDC);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingVaultUSDC);
        // console.log(userPendingVaultBTC); // 11599 -> 2.39 USD
        // console.log(userPendingVaultETH); // 9211861649819857 -> 1.65 USD
        // console.log(userPendingVaultUSDC); // 0.843988 USD
    }

    function testClaim() public {
        testHarvest();
        // Record variable before claim
        uint userPendingRewardWBTC = vaultBTC.getUserPendingReward(address(this));
        uint userPendingRewardWETH = vaultETH.getUserPendingReward(address(this));
        uint userPendingRewardUSDC = vaultUSDC.getUserPendingReward(address(this));
        // Claim
        vaultBTC.claim();
        vaultETH.claim();
        vaultUSDC.claim();
        // Assertion check
        assertGt(WBTC.balanceOf(address(this)), 0);
        assertGt(WETH.balanceOf(address(this)), 0);
        assertGt(USDC.balanceOf(address(this)), 0);
        assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
        assertEq(USDC.balanceOf(address(this)), userPendingRewardUSDC);
        (, uint rewardStartAtWBTC) = vaultBTC.userInfo(address(this));
        assertGt(rewardStartAtWBTC, 0);
        (, uint rewardStartAtWETH) = vaultETH.userInfo(address(this));
        assertGt(rewardStartAtWETH, 0);
        (, uint rewardStartAtUSDC) = vaultUSDC.userInfo(address(this));
        assertGt(rewardStartAtUSDC, 0);
        uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
        uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
        uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        assertLe(lastATokenAmtWBTC, 1);
        assertLe(lastATokenAmtWETH, 1);
        assertLe(lastATokenAmtUSDC, 1);
        assertLe(aWBTC.balanceOf(address(vaultBTC)), 1);
        assertLe(aWETH.balanceOf(address(vaultETH)), 1);
        assertLe(aUSDC.balanceOf(address(vaultUSDC)), 1);
    }

    function testPauseContract() public {
        deal(address(WETH), address(this), 10 ether);
        WETH.approve(address(vaultBTC), type(uint).max);
        // Pause contract and test deposit
        hoax(owner);
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultBTC.deposit(WETH, 10 ether, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultBTC.unPauseContract();
        vaultBTC.deposit(WETH, 10 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultBTC.pauseContract();
        vaultBTC.withdraw(WETH, vaultBTC.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbCrvPolyTri vault_ = new PbCrvPolyTri();
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
        vaultBTC.initialize(IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultETH.initialize(IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUSDC.initialize(IERC20Upgradeable(address(0)), address(0));
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
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/PbCrvArbTri.sol";
import "../src/PbProxy.sol";

contract PbCrvArbTriTest is Test {
    IPool pool = IPool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    IGauge gauge = IGauge(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    IERC20Upgradeable CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable USDT = IERC20Upgradeable(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2);
    PbCrvArbTri vaultBTC;
    PbCrvArbTri vaultETH;
    PbCrvArbTri vaultUSDT;
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    IERC20Upgradeable aUSDT;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // Deploy implementation contract
        // PbCrvArbTri vaultImpl = new PbCrvArbTri();

        // // Deploy BTC reward proxy contract
        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(WBTC),
        //         address(6288)
        //     )
        // );
        // vaultBTC = PbCrvArbTri(address(proxy));
        vaultBTC = PbCrvArbTri(payable(0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5));
        // hoax(owner);
        // vaultBTC.upgradeTo(address(vaultImpl));

        // // Deploy ETH reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(WETH),
        //         address(6288)
        //     )
        // );
        // vaultETH = PbCrvArbTri(address(proxy));
        vaultETH = PbCrvArbTri(payable(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631));
        // hoax(owner);
        // vaultETH.upgradeTo(address(vaultImpl));

        // // Deploy USDT reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(USDT),
        //         address(6288)
        //     )
        // );
        // vaultUSDT = PbCrvArbTri(address(proxy));
        vaultUSDT = PbCrvArbTri(payable(0x8Ae32c034dAcd85a79CFd135050FCb8e6D4207D8));
        // hoax(owner);
        // vaultUSDT.upgradeTo(address(vaultImpl));

        // Initialize aToken
        aWBTC = IERC20Upgradeable(vaultBTC.aToken());
        aWETH = IERC20Upgradeable(vaultETH.aToken());
        aUSDT = IERC20Upgradeable(vaultUSDT.aToken());

        // vm.startPrank(owner);
        // vaultBTC.switchGauge();
        // vaultETH.switchGauge();
        // vaultUSDT.switchGauge();
        // vm.stopPrank();
    }

    function testDeposit() public {
        // Deposit BTC for BTC reward
        deal(address(WBTC), address(this), 1e8);
        WBTC.approve(address(vaultBTC), type(uint).max);
        uint[3] memory amounts = [0, WBTC.balanceOf(address(this)), 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultBTC.deposit(WBTC, WBTC.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit ETH for ETH reward
        // deal(address(WETH), address(this), 10 ether);
        uint ETHAmt = 10 ether;
        // WETH.approve(address(vaultETH), type(uint).max);
        // amounts = [0, 0, WETH.balanceOf(address(this))];
        amounts = [0, 0, ETHAmt];
        amountOut = pool.calc_token_amount(amounts, true);
        // vaultETH.deposit(WETH, WETH.balanceOf(address(this)), amountOut * 99 / 100);
        vaultETH.deposit{value: ETHAmt}(WETH, ETHAmt, amountOut * 99 / 100);
        // Deposit USDT for USDT reward
        deal(address(USDT), address(this), 10000e6);
        USDT.approve(address(vaultUSDT), type(uint).max);
        amounts = [USDT.balanceOf(address(this)), 0, 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultUSDT.deposit(USDT, USDT.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit lpToken for BTC reward
        deal(address(lpToken), address(this), 1 ether);
        lpToken.approve(address(vaultBTC), type(uint).max);
        vaultBTC.deposit(lpToken, lpToken.balanceOf(address(this)), 0);
        // Assertion check
        assertGt(vaultBTC.getAllPool(), 0);
        assertGt(vaultETH.getAllPool(), 0);
        assertGt(vaultUSDT.getAllPool(), 0);
        uint balWBTC = vaultBTC.getUserBalance(address(this));
        uint balWETH = vaultETH.getUserBalance(address(this));
        uint balUSDT = vaultUSDT.getUserBalance(address(this));
        assertGt(balUSDT, 0);
        assertGt(balWBTC, 0);
        assertGt(balWETH, 0);
        assertGt(balWBTC, balWETH);
        assertGt(balWETH, balUSDT);
        uint balWBTC_USD = vaultBTC.getUserBalanceInUSD(address(this));
        uint balWETH_USD = vaultETH.getUserBalanceInUSD(address(this));
        uint balUSDT_USD = vaultUSDT.getUserBalanceInUSD(address(this));
        assertGt(balUSDT_USD, 0);
        assertGt(balWBTC_USD, 0);
        assertGt(balWETH_USD, 0);
        assertGt(balWBTC_USD, balWETH_USD);
        assertGt(balWETH_USD, balUSDT_USD);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertEq(USDT.balanceOf(address(vaultUSDT)), 0);
        assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        assertEq(lpToken.balanceOf(address(vaultETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultUSDT)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        // Withdraw WBTC from WBTC reward
        uint amountOut = pool.calc_withdraw_one_coin(vaultBTC.getUserBalance(address(this)), uint(1));
        vaultBTC.withdraw(WBTC, vaultBTC.getUserBalance(address(this)), amountOut * 99 / 100);
        // Withdraw ETH from WETH reward
        uint ETHAmtBef = address(this).balance;
        amountOut = pool.calc_withdraw_one_coin(vaultETH.getUserBalance(address(this)), uint(2));
        vaultETH.withdraw(WETH, vaultETH.getUserBalance(address(this)), amountOut * 99 / 100);
        // Withdraw USDT from USDT reward
        amountOut = pool.calc_withdraw_one_coin(vaultUSDT.getUserBalance(address(this)), uint(0));
        vaultUSDT.withdraw(USDT, vaultUSDT.getUserBalance(address(this)), amountOut * 99 / 100);
        // Assertion check
        assertGt(WBTC.balanceOf(address(this)), 0);
        assertGt(address(this).balance, ETHAmtBef);
        assertGt(USDT.balanceOf(address(this)), 0);
        // assertEq(vaultBTC.getAllPool(), 0);
        // assertEq(vaultBTC.getAllPoolInUSD(), 0);
        // assertEq(vaultBTC.getUserBalance(address(this)), 0);
        // assertEq(vaultBTC.getUserBalanceInUSD(address(this)), 0);
        // assertEq(vaultETH.getAllPool(), 0);
        // assertEq(vaultETH.getAllPoolInUSD(), 0);
        // assertEq(vaultETH.getUserBalance(address(this)), 0);
        // assertEq(vaultETH.getUserBalanceInUSD(address(this)), 0);
        // assertEq(vaultUSDT.getAllPool(), 0);
        // assertEq(vaultUSDT.getAllPoolInUSD(), 0);
        // assertEq(vaultUSDT.getUserBalance(address(this)), 0);
        // assertEq(vaultUSDT.getUserBalanceInUSD(address(this)), 0);
    }

    receive() external payable {}

    function testHarvest() public {
        testDeposit();
        // Assume reward
        // deal(address(CRV), address(gauge), CRV.balanceOf(address(gauge)) + 10000 ether);
        skip(864000);
        assertGt(vaultBTC.getPoolPendingReward(), 0);
        assertGt(vaultETH.getPoolPendingReward(), 0);
        assertGt(vaultUSDT.getPoolPendingReward(), 0);
        // Harvest BTC reward
        vaultBTC.harvest();
        // Harvest ETH reward
        vaultETH.harvest();
        // Harvest USDT reward
        vaultUSDT.harvest();
        // Assertion check
        assertEq(CRV.balanceOf(address(vaultBTC)), 0);
        assertEq(CRV.balanceOf(address(vaultETH)), 0);
        assertEq(CRV.balanceOf(address(vaultUSDT)), 0);
        assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        assertGt(aWBTC.balanceOf(address(vaultBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultETH)), 0);
        assertGt(aWETH.balanceOf(address(vaultETH)), 0);
        assertEq(USDT.balanceOf(address(vaultUSDT)), 0);
        assertGt(aUSDT.balanceOf(address(vaultUSDT)), 0);
        assertGt(WBTC.balanceOf(owner), 0); // treasury fee
        assertGt(WETH.balanceOf(owner), 0); // treasury fee
        assertGt(USDT.balanceOf(owner), 0); // treasury fee
        assertGt(vaultBTC.accRewardPerlpToken(), 0);
        assertGt(vaultETH.accRewardPerlpToken(), 0);
        assertGt(vaultUSDT.accRewardPerlpToken(), 0);
        assertGt(vaultBTC.lastATokenAmt(), 0);
        assertGt(vaultETH.lastATokenAmt(), 0);
        assertGt(vaultUSDT.lastATokenAmt(), 0);
        assertGt(vaultBTC.accRewardTokenAmt(), 0);
        assertGt(vaultETH.accRewardTokenAmt(), 0);
        assertGt(vaultUSDT.accRewardTokenAmt(), 0);
        // Assume aToken increase
        // aWBTC
        hoax(0x004c718103feD0bf75f2A02C3Da7eA2332137fAC);
        aWBTC.transfer(address(vaultBTC), 1e5);
        uint accRewardPerlpTokenWBTC = vaultBTC.accRewardPerlpToken();
        uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
        uint userPendingVaultBTC = vaultBTC.getUserPendingReward(address(this));
        // aWETH
        hoax(0x4196c40De33062ce03070f058922BAA99B28157B);
        aWETH.transfer(address(vaultETH), 1e16);
        uint accRewardPerlpTokenWETH = vaultETH.accRewardPerlpToken();
        uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
        uint userPendingVaultETH = vaultETH.getUserPendingReward(address(this));
        // aUSDT
        hoax(0x1E6310BCe96E5C2AF939942CCC46462D06a88eE0);
        aUSDT.transfer(address(vaultUSDT), 10e6);
        uint accRewardPerlpTokenUSDT = vaultUSDT.accRewardPerlpToken();
        uint lastATokenAmtUSDT = vaultUSDT.lastATokenAmt();
        uint userPendingVaultUSDT = vaultUSDT.getUserPendingReward(address(this));
        // Harvest again
        vaultBTC.harvest();
        vaultETH.harvest();
        vaultUSDT.harvest();
        // Assertion check
        assertGt(vaultBTC.accRewardPerlpToken(), accRewardPerlpTokenWBTC);
        assertGt(vaultBTC.lastATokenAmt(), lastATokenAmtWBTC);
        assertGt(vaultBTC.getUserPendingReward(address(this)), userPendingVaultBTC);
        assertGt(vaultETH.accRewardPerlpToken(), accRewardPerlpTokenWETH);
        assertGt(vaultETH.lastATokenAmt(), lastATokenAmtWETH);
        assertGt(vaultETH.getUserPendingReward(address(this)), userPendingVaultETH);
        assertGt(vaultUSDT.accRewardPerlpToken(), accRewardPerlpTokenUSDT);
        assertGt(vaultUSDT.lastATokenAmt(), lastATokenAmtUSDT);
        assertGt(vaultUSDT.getUserPendingReward(address(this)), userPendingVaultUSDT);
        // console.log(userPendingVaultBTC); // 95700 -> 19.84 USD
        // console.log(userPendingVaultETH); // 9211861649819857 -> 10.25 USD
        // console.log(userPendingVaultUSDT); // 9.216307 USD
    }

    function testClaim() public {
        testHarvest();
        // Record variable before claim
        uint userPendingRewardWBTC = vaultBTC.getUserPendingReward(address(this));
        uint userPendingRewardWETH = vaultETH.getUserPendingReward(address(this));
        uint userPendingRewardUSDT = vaultUSDT.getUserPendingReward(address(this));
        // Claim
        vaultBTC.claim();
        vaultETH.claim();
        vaultUSDT.claim();
        // Assertion check
        assertGt(WBTC.balanceOf(address(this)), 0);
        assertGt(WETH.balanceOf(address(this)), 0);
        assertGt(USDT.balanceOf(address(this)), 0);
        assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
        assertEq(USDT.balanceOf(address(this)), userPendingRewardUSDT);
        (, uint rewardStartAtWBTC) = vaultBTC.userInfo(address(this));
        assertGt(rewardStartAtWBTC, 0);
        (, uint rewardStartAtWETH) = vaultETH.userInfo(address(this));
        assertGt(rewardStartAtWETH, 0);
        (, uint rewardStartAtUSDT) = vaultUSDT.userInfo(address(this));
        assertGt(rewardStartAtUSDT, 0);
        // uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
        // uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
        // uint lastATokenAmtUSDT = vaultUSDT.lastATokenAmt();
        // assertLe(lastATokenAmtWBTC, 1);
        // assertLe(lastATokenAmtWETH, 1);
        // assertLe(lastATokenAmtUSDT, 1);
        // assertLe(aWBTC.balanceOf(address(vaultBTC)), 1);
        // assertLe(aWETH.balanceOf(address(vaultETH)), 1);
        // assertLe(aUSDT.balanceOf(address(vaultUSDT)), 1);
    }

    function testPauseContract() public {
        // deal(address(WETH), address(this), 10 ether);
        // WETH.approve(address(vaultBTC), type(uint).max);
        // Pause contract and test deposit
        hoax(owner);
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultBTC.deposit{value: 10 ether}(WETH, 10 ether, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultBTC.unPauseContract();
        vaultBTC.deposit{value: 10 ether}(WETH, 10 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultBTC.pauseContract();
        vaultBTC.withdraw(WETH, vaultBTC.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbCrvArbTri vault_ = new PbCrvArbTri();
        startHoax(owner);
        vaultBTC.upgradeTo(address(vault_));
        vaultETH.upgradeTo(address(vault_));
        vaultUSDT.upgradeTo(address(vault_));
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
        vaultUSDT.setYieldFeePerc(1000);
        assertEq(vaultUSDT.yieldFeePerc(), 1000);
        vaultUSDT.setTreasury(address(1));
        assertEq(vaultUSDT.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultBTC.owner(), owner);
        assertEq(vaultETH.owner(), owner);
        assertEq(vaultUSDT.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultBTC.transferOwnership(address(1));
        vaultETH.transferOwnership(address(1));
        vaultUSDT.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultBTC.initialize(IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultETH.initialize(IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUSDT.initialize(IERC20Upgradeable(address(0)), address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDT.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDT.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDT.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDT.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultBTC.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultETH.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUSDT.setTreasury(address(0));
    }
}
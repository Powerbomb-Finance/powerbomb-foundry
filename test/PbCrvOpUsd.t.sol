// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PbCrvOpUsd.sol";
import "../src/PbProxy.sol";

contract PbCrvOpUsdTest is Test {
    IPool pool = IPool(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IGauge gauge = IGauge(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
    IERC20Upgradeable CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable DAI = IERC20Upgradeable(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20Upgradeable SUSD = IERC20Upgradeable(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable USDT = IERC20Upgradeable(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    PbCrvOpUsd vaultBTC;
    PbCrvOpUsd vaultETH;
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // Deploy implementation contract
        PbCrvOpUsd vaultImpl = new PbCrvOpUsd();

        // Deploy BTC reward proxy contract
        PbProxy proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(WBTC),
                address(6288)
            )
        );
        vaultBTC = PbCrvOpUsd(address(proxy));
        // vaultBTC = PbCrvOpUsd(0xE616e7e282709d8B05821a033B43a358a6ea8408);

        // Deploy ETH reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(WETH),
                address(6288)
            )
        );
        vaultETH = PbCrvOpUsd(address(proxy));
        // vaultETH = PbCrvOpUsd(0xBE6A4db3480EFccAb2281F30fe97b897BeEf408c);

        // Initialize aToken
        aWBTC = IERC20Upgradeable(vaultBTC.aToken());
        aWETH = IERC20Upgradeable(vaultETH.aToken());
    }

    function testDeposit() public {
        // Deposit SUSD for BTC reward
        deal(address(SUSD), address(this), 10000e6);
        SUSD.approve(address(vaultBTC), type(uint).max);
        uint[4] memory amounts = [SUSD.balanceOf(address(this)), 0, 0, 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultBTC.deposit(SUSD, SUSD.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit DAI for ETH reward
        deal(address(DAI), address(this), 10000 ether);
        DAI.approve(address(vaultETH), type(uint).max);
        amounts = [0, DAI.balanceOf(address(this)), 0, 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultETH.deposit(DAI, DAI.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit USDC for BTC reward
        deal(address(USDC), address(this), 10000e6);
        USDC.approve(address(vaultBTC), type(uint).max);
        amounts = [0, 0, USDC.balanceOf(address(this)), 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultBTC.deposit(USDC, USDC.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit USDT for ETH reward
        deal(address(USDT), address(this), 10000e6);
        USDT.approve(address(vaultETH), type(uint).max);
        amounts = [0, 0, 0, USDT.balanceOf(address(this))];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultETH.deposit(USDT, USDT.balanceOf(address(this)), amountOut * 99 / 100);
        // // Deposit lpToken for BTC reward
        // deal(address(lpToken), address(this), 10000 ether);
        // lpToken.approve(address(vaultBTC), type(uint).max);
        // vaultBTC.deposit(lpToken, lpToken.balanceOf(address(this)), 0);
        // // Assertion check
        // // console.log(vaultBTC.getAllPool());
        // // console.log(vaultETH.getAllPool());
        // assertGt(vaultBTC.getAllPool(), 0);
        // assertGt(vaultETH.getAllPool(), 0);
        // uint balWBTC = vaultBTC.getUserBalance(address(this));
        // uint balWETH = vaultETH.getUserBalance(address(this));
        // // console.log(balWBTC);
        // // console.log(balWETH);
        // assertGt(balWBTC, 0);
        // assertGt(balWETH, 0);
        // assertGt(balWBTC, balWETH);
        // uint balWBTC_USD = vaultBTC.getUserBalanceInUSD(address(this));
        // uint balWETH_USD = vaultETH.getUserBalanceInUSD(address(this));
        // // console.log(balWBTC_USD);
        // // console.log(balWETH_USD);
        // assertGt(balWBTC_USD, 0);
        // assertGt(balWETH_USD, 0);
        // assertGt(balWBTC_USD, balWETH_USD);
        // assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
        // assertEq(WETH.balanceOf(address(vaultETH)), 0);
        // assertEq(lpToken.balanceOf(address(vaultBTC)), 0);
        // assertEq(lpToken.balanceOf(address(vaultETH)), 0);
    }

    // function testWithdraw() public {
    //     testDeposit();
    //     vm.roll(block.number + 1);
    //     // Withdraw USDT from WBTC reward
    //     uint amountOut = pool.calc_withdraw_one_coin(vaultBTC.getUserBalance(address(this)), int128(1));
    //     vaultBTC.withdraw(USDT, vaultBTC.getUserBalance(address(this)), amountOut * 99 / 100);
    //     // Withdraw USDC from WETH reward
    //     amountOut = pool.calc_withdraw_one_coin(vaultETH.getUserBalance(address(this)), int128(0));
    //     vaultETH.withdraw(USDC, vaultETH.getUserBalance(address(this)), amountOut * 99 / 100);
    //     // Assertion check
    //     assertEq(vaultBTC.getAllPool(), 0);
    //     assertEq(vaultBTC.getAllPoolInUSD(), 0);
    //     assertEq(vaultBTC.getUserBalance(address(this)), 0);
    //     assertEq(vaultBTC.getUserBalanceInUSD(address(this)), 0);
    //     assertEq(vaultETH.getAllPool(), 0);
    //     assertEq(vaultETH.getAllPoolInUSD(), 0);
    //     assertEq(vaultETH.getUserBalance(address(this)), 0);
    //     // console.log(USDC.balanceOf(address(this)));
    //     // console.log(USDT.balanceOf(address(this)));
    // }

    // function testHarvest() public {
    //     testDeposit();
    //     // Assume reward
    //     deal(address(CRV), address(gauge), CRV.balanceOf(address(gauge)) + 10000 ether);
    //     // Harvest BTC reward
    //     vaultBTC.harvest();
    //     // Harvest ETH reward
    //     vaultETH.harvest();
    //     // Assertion check
    //     assertEq(CRV.balanceOf(address(vaultBTC)), 0);
    //     assertEq(CRV.balanceOf(address(vaultETH)), 0);
    //     assertEq(WBTC.balanceOf(address(vaultBTC)), 0);
    //     assertGt(aWBTC.balanceOf(address(vaultBTC)), 0);
    //     assertEq(WETH.balanceOf(address(vaultETH)), 0);
    //     assertGt(aWETH.balanceOf(address(vaultETH)), 0);
    //     assertGt(WBTC.balanceOf(owner), 0); // treasury fee
    //     assertGt(WETH.balanceOf(owner), 0); // treasury fee
    //     assertGt(vaultBTC.accRewardPerlpToken(), 0);
    //     assertGt(vaultETH.accRewardPerlpToken(), 0);
    //     assertGt(vaultBTC.lastATokenAmt(), 0);
    //     assertGt(vaultETH.lastATokenAmt(), 0);
    //     // Assume aToken increase
    //     // aWBTC
    //     hoax(0x0eaE0b9EE583524098bca227478cc43413b7F4B9);
    //     aWBTC.transfer(address(vaultBTC), 1e5);
    //     uint accRewardPerlpTokenWBTC = vaultBTC.accRewardPerlpToken();
    //     uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
    //     uint userPendingVaultBTC = vaultBTC.getUserPendingReward(address(this));
    //     // aWETH
    //     hoax(0x7576B7a1D278E3004dd37BBEB90E0b08cA70a1b9);
    //     aWETH.transfer(address(vaultETH), 1e16);
    //     uint accRewardPerlpTokenWETH = vaultETH.accRewardPerlpToken();
    //     uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
    //     uint userPendingVaultETH = vaultETH.getUserPendingReward(address(this));

    //     // Harvest again
    //     vaultBTC.harvest();
    //     vaultETH.harvest();
    //     // Assertion check
    //     assertGt(vaultBTC.accRewardPerlpToken(), accRewardPerlpTokenWBTC);
    //     assertGt(vaultBTC.lastATokenAmt(), lastATokenAmtWBTC);
    //     assertGt(vaultBTC.getUserPendingReward(address(this)), userPendingVaultBTC);
    //     assertGt(vaultETH.accRewardPerlpToken(), accRewardPerlpTokenWETH);
    //     assertGt(vaultETH.lastATokenAmt(), lastATokenAmtWETH);
    //     assertGt(vaultETH.getUserPendingReward(address(this)), userPendingVaultETH);
    //     // console.log(userPendingVaultBTC); // 45631 -> 9.16 USD
    //     // console.log(userPendingVaultETH); // 4259166230884756 -> 4.58 USD
    // }

    // function testClaim() public {
    //     testHarvest();
    //     // Record variable before claim
    //     uint userPendingRewardWBTC = vaultBTC.getUserPendingReward(address(this));
    //     uint userPendingRewardWETH = vaultETH.getUserPendingReward(address(this));
    //     // Claim
    //     vaultBTC.claim();
    //     vaultETH.claim();
    //     // Assertion check
    //     assertGt(WBTC.balanceOf(address(this)), 0);
    //     assertGt(WETH.balanceOf(address(this)), 0);
    //     assertEq(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
    //     assertEq(WETH.balanceOf(address(this)), userPendingRewardWETH);
    //     (, uint rewardStartAtWBTC) = vaultBTC.userInfo(address(this));
    //     assertGt(rewardStartAtWBTC, 0);
    //     (, uint rewardStartAtWETH) = vaultETH.userInfo(address(this));
    //     assertGt(rewardStartAtWETH, 0);
    //     uint lastATokenAmtWBTC = vaultBTC.lastATokenAmt();
    //     uint lastATokenAmtWETH = vaultETH.lastATokenAmt();
    //     assertLe(lastATokenAmtWBTC, 1);
    //     assertLe(lastATokenAmtWETH, 1);
    //     assertLe(aWBTC.balanceOf(address(vaultBTC)), 1);
    //     assertLe(aWETH.balanceOf(address(vaultETH)), 1);
    // }

    // function testPauseContract() public {
    //     deal(address(USDC), address(this), 10000e6);
    //     USDC.approve(address(vaultBTC), type(uint).max);
    //     // Pause contract and test deposit
    //     hoax(owner);
    //     vaultBTC.pauseContract();
    //     vm.expectRevert(bytes("Pausable: paused"));
    //     vaultBTC.deposit(USDC, 10000e6, 0);
    //     // Unpause contract and test deposit
    //     hoax(owner);
    //     vaultBTC.unPauseContract();
    //     vaultBTC.deposit(USDC, 10000e6, 0);
    //     vm.roll(block.number + 1);
    //     // Pause contract and test withdraw
    //     hoax(owner);
    //     vaultBTC.pauseContract();
    //     vaultBTC.withdraw(USDC, vaultBTC.getUserBalance(address(this)), 0);
    // }

    // function testUpgrade() public {
    //     PbCrvOpUsd vault_ = new PbCrvOpUsd();
    //     startHoax(owner);
    //     vaultBTC.upgradeTo(address(vault_));
    //     vaultETH.upgradeTo(address(vault_));
    // }

    // function testSetter() public {
    //     startHoax(owner);
    //     vaultBTC.setYieldFeePerc(1000);
    //     assertEq(vaultBTC.yieldFeePerc(), 1000);
    //     vaultBTC.setTreasury(address(1));
    //     assertEq(vaultBTC.treasury(), address(1));
    //     vaultETH.setYieldFeePerc(1000);
    //     assertEq(vaultETH.yieldFeePerc(), 1000);
    //     vaultETH.setTreasury(address(1));
    //     assertEq(vaultETH.treasury(), address(1));
    // }

    // function testAuthorization() public {
    //     assertEq(vaultBTC.owner(), owner);
    //     assertEq(vaultETH.owner(), owner);
    //     // TransferOwnership
    //     startHoax(owner);
    //     vaultBTC.transferOwnership(address(1));
    //     vaultETH.transferOwnership(address(1));
    //     // Vault
    //     vm.expectRevert(bytes("Initializable: contract is already initialized"));
    //     vaultBTC.initialize(IERC20Upgradeable(address(0)), address(0));
    //     vm.expectRevert(bytes("Initializable: contract is already initialized"));
    //     vaultETH.initialize(IERC20Upgradeable(address(0)), address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultBTC.pauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultETH.pauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultBTC.unPauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultETH.unPauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultBTC.upgradeTo(address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultETH.upgradeTo(address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultBTC.setYieldFeePerc(0);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultETH.setYieldFeePerc(0);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultBTC.setTreasury(address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultETH.setTreasury(address(0));
    // }
}

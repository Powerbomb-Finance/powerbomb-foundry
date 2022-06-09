// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

import "../src/PbCrvTri.sol";
import "../src/PbCrvTriProxy.sol";
import "../src/PbCrvTriReward.sol";
import "../src/PbCrvTriRewardBTC.sol";
import "../src/PbCrvTriRewardUSDC.sol";

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbCrvTriTest is Test {
    IERC20Upgradeable constant USDT = IERC20Upgradeable(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable constant crv3crypto = IERC20Upgradeable(0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2);
    IPool constant pool = IPool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    IGauge constant gauge = IGauge(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    IERC20Upgradeable aWBTC;
    IERC20Upgradeable aWETH;
    IERC20Upgradeable aUSDC;

    PbCrvTri vault;
    PbCrvTriReward rewardWETH;
    PbCrvTriRewardBTC rewardWBTC;
    PbCrvTriRewardUSDC rewardUSDC;

    function setUp() public {
        // Deploy vault
        vault = new PbCrvTri();
        PbCrvTriProxy vaultProxy = new PbCrvTriProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize()"))
            )
        );
        vault = PbCrvTri(address(vaultProxy));
        // Deploy reward in WETH
        rewardWETH = new PbCrvTriReward();
        PbCrvTriProxy rewardProxy = new PbCrvTriProxy(
            address(rewardWETH),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(vault), // _vault
                address(6288) // _treasury
            )
        );
        rewardWETH = PbCrvTriReward(address(rewardProxy));
        // Deploy reward in WBTC
        rewardWBTC = new PbCrvTriRewardBTC();
        PbCrvTriProxy rewardProxyWBTC = new PbCrvTriProxy(
            address(rewardWBTC),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(vault), // _vault
                address(6288) // _treasury
            )
        );
        rewardWBTC = PbCrvTriRewardBTC(address(rewardProxyWBTC));
        // Deploy reward in USDC
        rewardUSDC = new PbCrvTriRewardUSDC();
        PbCrvTriProxy rewardProxyUSDC = new PbCrvTriProxy(
            address(rewardUSDC),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                address(vault), // _vault
                address(6288) // _treasury
            )
        );
        rewardUSDC = PbCrvTriRewardUSDC(address(rewardProxyUSDC));
        // Add reward contracts to vault
        vault.addNewReward(address(rewardWETH), address(WETH));
        vault.addNewReward(address(rewardWBTC), address(WBTC));
        vault.addNewReward(address(rewardUSDC), address(USDC));
        // Initialize aToken
        aWBTC = IERC20Upgradeable(rewardWBTC.aToken());
        aWETH = IERC20Upgradeable(rewardWETH.aToken());
        aUSDC = IERC20Upgradeable(rewardUSDC.aToken());
    }

    function testRewardInfo() public {
        // WETH
        IReward _rewardWETH = vault.rewardInfo(address(WETH));
        assertEq(address(_rewardWETH), address(rewardWETH));
        assertEq(address(_rewardWETH), vault.rewards(0));
        // WBTC
        IReward _rewardWBTC = vault.rewardInfo(address(WBTC));
        assertEq(address(_rewardWBTC), address(rewardWBTC));
        assertEq(address(_rewardWBTC), vault.rewards(1));
        // USDC
        IReward _rewardUSDC = vault.rewardInfo(address(USDC));
        assertEq(address(_rewardUSDC), address(rewardUSDC));
        assertEq(address(_rewardUSDC), vault.rewards(2));
    }

    function testDeposit() public {
        // Deposit ETH for ETH reward
        deal(address(WETH), address(this), 10 ether);
        WETH.approve(address(vault), type(uint).max);
        uint[3] memory amounts = [0, 0, WETH.balanceOf(address(this))];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vault.deposit(WETH, WETH.balanceOf(address(this)), amountOut * 95 / 100, address(WETH));
        // Deposit BTC for BTC reward
        deal(address(WBTC), address(this), 1e8);
        WBTC.approve(address(vault), type(uint).max);
        amounts = [0, WBTC.balanceOf(address(this)), 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vault.deposit(WBTC, WBTC.balanceOf(address(this)), amountOut * 95 / 100, address(WBTC));
        // Deposit USDT for USDC reward
        deal(address(USDT), address(this), 10000e6);
        USDT.approve(address(vault), type(uint).max);
        amounts = [USDT.balanceOf(address(this)), 0, 0];
        amountOut = pool.calc_token_amount(amounts, true);
        vault.deposit(USDT, USDT.balanceOf(address(this)), amountOut * 95 / 100, address(USDC));
        // Deposit crv3crypto for BTC reward
        deal(address(crv3crypto), address(this), 1 ether);
        crv3crypto.approve(address(vault), type(uint).max);
        vault.deposit(crv3crypto, crv3crypto.balanceOf(address(this)), 0, address(WBTC));
        // Assertion check
        assertGt(vault.getAllPool(), 0);
        uint balUSDC = vault.getUserBalance(address(this), address(USDC));
        uint balWBTC = vault.getUserBalance(address(this), address(WBTC));
        uint balWETH = vault.getUserBalance(address(this), address(WETH));
        assertGt(balUSDC, 0);
        assertGt(balWBTC, 0);
        assertGt(balWETH, 0);
        assertGt(balWBTC, balWETH);
        assertGt(balWETH, balUSDC);
        uint balUSDC_USD = vault.getUserBalanceInUSD(address(this), address(USDC));
        uint balWBTC_USD = vault.getUserBalanceInUSD(address(this), address(WBTC));
        uint balWETH_USD = vault.getUserBalanceInUSD(address(this), address(WETH));
        assertGt(balUSDC_USD, 0);
        assertGt(balWBTC_USD, 0);
        assertGt(balWETH_USD, 0);
        assertGt(balWBTC_USD, balWETH_USD);
        assertGt(balWETH_USD, balUSDC_USD);
        assertEq(USDT.balanceOf(address(vault)), 0);
        assertEq(WETH.balanceOf(address(vault)), 0);
        assertEq(WBTC.balanceOf(address(vault)), 0);
        assertEq(crv3crypto.balanceOf(address(vault)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        // Withdraw WBTC from WBTC reward
        uint amountOut = pool.calc_withdraw_one_coin(vault.getUserBalance(address(this), address(WBTC)), 1);
        vault.withdraw(WBTC, vault.getUserBalance(address(this), address(WBTC)), amountOut * 95 / 100, address(WBTC));
        // Withdraw WETH from WETH reward
        amountOut = pool.calc_withdraw_one_coin(vault.getUserBalance(address(this), address(WETH)), 2);
        vault.withdraw(WETH, vault.getUserBalance(address(this), address(WETH)), amountOut * 95 / 100, address(WETH));
        // Withdraw USDT from USDC reward
        amountOut = pool.calc_withdraw_one_coin(vault.getUserBalance(address(this), address(USDC)), 0);
        vault.withdraw(USDT, vault.getUserBalance(address(this), address(USDC)), amountOut * 95 / 100, address(USDC));
        // Assertion check
        assertEq(vault.getUserBalance(address(this), address(WBTC)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this), address(WBTC)), 0);
        assertEq(vault.getUserBalance(address(this), address(WETH)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this), address(WETH)), 0);
        assertEq(vault.getUserBalance(address(this), address(USDC)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this), address(USDC)), 0);
        assertEq(vault.getAllPool(), 0);
        assertEq(vault.getAllPoolInUSD(), 0);
    }

    function testHarvest() public {
        testDeposit();
        // Assume reward
        deal(address(CRV), address(gauge), CRV.balanceOf(address(gauge)) + 10000 ether);
        // Harvest
        vault.harvest();
        // Assertion check
        assertLt(CRV.balanceOf(address(vault)), 100); // same as 0
        assertEq(CRV.balanceOf(address(rewardWBTC)), 0);
        assertEq(WETH.balanceOf(address(rewardWBTC)), 0);
        assertGt(aWBTC.balanceOf(address(rewardWBTC)), 0);
        assertEq(CRV.balanceOf(address(rewardWETH)), 0);
        assertEq(WETH.balanceOf(address(rewardWETH)), 0);
        assertGt(aWETH.balanceOf(address(rewardWETH)), 0);
        assertEq(CRV.balanceOf(address(rewardUSDC)), 0);
        assertEq(USDC.balanceOf(address(rewardUSDC)), 0);
        assertGt(aUSDC.balanceOf(address(rewardUSDC)), 0);
        assertGt(WBTC.balanceOf(address(6288)), 0); // treasury fee
        assertGt(WETH.balanceOf(address(6288)), 0); // treasury fee
        assertGt(USDC.balanceOf(address(6288)), 0); // treasury fee
        assertGt(rewardWETH.accRewardPerlpToken(), 0);
        assertGt(rewardWBTC.accRewardPerlpToken(), 0);
        assertGt(rewardUSDC.accRewardPerlpToken(), 0);
        assertGt(rewardWETH.lastATokenAmt(), 0);
        assertGt(rewardWBTC.lastATokenAmt(), 0);
        assertGt(rewardUSDC.lastATokenAmt(), 0);
        // Assume aToken increase
        // aWBTC
        hoax(0x1be2655C587C39610751176ce3C6f3c7018D61c1);
        aWBTC.transfer(address(rewardWBTC), 1e5);
        uint accRewardPerlpTokenWBTC = rewardWBTC.accRewardPerlpToken();
        uint lastATokenAmtWBTC = rewardWBTC.lastATokenAmt();
        uint pendingRewardWBTC = vault.getUserPendingReward(address(this), address(WBTC));
        // aWETH
        hoax(0x1be2655C587C39610751176ce3C6f3c7018D61c1);
        aWETH.transfer(address(rewardWETH), 1e16);
        uint accRewardPerlpTokenWETH = rewardWETH.accRewardPerlpToken();
        uint lastATokenAmtWETH = rewardWETH.lastATokenAmt();
        uint pendingRewardWETH = vault.getUserPendingReward(address(this), address(WETH));
        // aUSDC
        hoax(0x0c67f4FfC902140C972eCAb356c9993e6cE8caF3);
        aUSDC.transfer(address(rewardUSDC), 10e6);
        uint accRewardPerlpTokenUSDC = rewardUSDC.accRewardPerlpToken();
        uint lastATokenAmtUSDC = rewardUSDC.lastATokenAmt();
        uint pendingRewardUSDC = vault.getUserPendingReward(address(this), address(USDC));
        // Harvest again
        vault.harvest();
        // Assertion check
        assertGt(rewardWBTC.accRewardPerlpToken(), accRewardPerlpTokenWBTC);
        assertGt(rewardWBTC.lastATokenAmt(), lastATokenAmtWBTC);
        assertGt(vault.getUserPendingReward(address(this), address(WBTC)), pendingRewardWBTC);
        assertGt(rewardWETH.accRewardPerlpToken(), accRewardPerlpTokenWETH);
        assertGt(rewardWETH.lastATokenAmt(), lastATokenAmtWETH);
        assertGt(vault.getUserPendingReward(address(this), address(WETH)), pendingRewardWETH);
        assertGt(rewardUSDC.accRewardPerlpToken(), accRewardPerlpTokenUSDC);
        assertGt(rewardUSDC.lastATokenAmt(), lastATokenAmtUSDC);
        assertGt(vault.getUserPendingReward(address(this), address(USDC)), pendingRewardUSDC);
        // console.log(pendingRewardWBTC); // 75599 = 22.8566 USD
        // console.log(pendingRewardWETH); // 7325538469961344 = 13.1809 USD
        // console.log(pendingRewardUSDC); // 7.331839 USD
    }

    function testClaim() public {
        testHarvest();
        // Record variable before claim
        uint pendingRewardWBTC = vault.getUserPendingReward(address(this), address(WBTC));
        uint pendingRewardWETH = vault.getUserPendingReward(address(this), address(WETH));
        uint pendingRewardUSDC = vault.getUserPendingReward(address(this), address(USDC));
        // Claim
        vault.claimReward();
        // Assertion check
        assertGt(WBTC.balanceOf(address(this)), 0);
        assertGt(WETH.balanceOf(address(this)), 0);
        assertGt(USDC.balanceOf(address(this)), 0);
        assertEq(WBTC.balanceOf(address(this)), pendingRewardWBTC);
        assertEq(WETH.balanceOf(address(this)), pendingRewardWETH);
        assertEq(USDC.balanceOf(address(this)), pendingRewardUSDC);
        (, uint rewardStartAtWBTC) = rewardWBTC.userInfo(address(this));
        assertGt(rewardStartAtWBTC, 0);
        (, uint rewardStartAtWETH) = rewardWETH.userInfo(address(this));
        assertGt(rewardStartAtWETH, 0);
        (, uint rewardStartAtUSDC) = rewardUSDC.userInfo(address(this));
        assertGt(rewardStartAtUSDC, 0);
        uint lastATokenAmtWBTC = rewardWBTC.lastATokenAmt();
        uint lastATokenAmtWETH = rewardWETH.lastATokenAmt();
        uint lastATokenAmtUSDC = rewardUSDC.lastATokenAmt();
        assertLe(lastATokenAmtWBTC, 1);
        assertLe(lastATokenAmtWETH, 1);
        assertLe(lastATokenAmtUSDC, 1);
        assertLe(aWBTC.balanceOf(address(rewardWBTC)), 1);
        assertLe(aWETH.balanceOf(address(rewardWETH)), 1);
        assertLe(aUSDC.balanceOf(address(rewardUSDC)), 1);
    }

    function testPauseContract() public {
        deal(address(WETH), address(this), 10 ether);
        WETH.approve(address(vault), type(uint).max);
        // Pause contract and test deposit
        vault.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(WETH, 10 ether, 0, address(WETH));
        // Unpause contract and test deposit
        vault.unPauseContract();
        vault.deposit(WETH, 10 ether, 0, address(WETH));
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        vault.pauseContract();
        vault.withdraw(WETH, vault.getUserBalance(address(this), address(WETH)), 0, address(WETH));
    }

    function testSetAndRemoveRewardContract() public {
        // Set current reward
        PbCrvTriReward _rewardUSDC = new PbCrvTriReward();
        _rewardUSDC.initialize(address(vault), address(6288));
        vault.setCurrentReward(address(_rewardUSDC), address(USDC), 2);
        assertEq(address(vault.rewardInfo(address(USDC))), address(_rewardUSDC));
        assertEq(vault.rewards(2), address(_rewardUSDC));
        assertGt(CRV.allowance(address(vault), address(_rewardUSDC)), 0);
        // Try deposit
        deal(address(WETH), address(this), 10 ether);
        WETH.approve(address(vault), type(uint).max);
        vault.deposit(WETH, 10 ether, 0, address(USDC));
        assertGt(_rewardUSDC.getAllPool(), 0);
        // Remove reward contract
        vm.roll(block.number + 1);
        vault.withdraw(WETH, vault.getUserBalance(address(this), address(USDC)), 0, address(USDC));
        vault.removeReward(address(USDC), 2);
        assertEq(vault.rewards(2), address(0));
        assertEq(address(vault.rewardInfo(address(USDC))), address(0));
    }

    function testUpgrade() public {
        PbCrvTri vault_ = new PbCrvTri();
        vault.upgradeTo(address(vault_));
        PbCrvTriReward reward_ = new PbCrvTriReward();
        vault.upgradeTo(address(reward_));
    }

    function testSetter() public {
        rewardUSDC.setVault(address(1));
        assertEq(rewardUSDC.vault(), address(1));
        rewardUSDC.setYieldFeePerc(1000);
        assertEq(rewardUSDC.yieldFeePerc(), 1000);
        rewardUSDC.setTreasury(address(1));
        assertEq(rewardUSDC.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vault.owner(), address(this));
        assertEq(rewardWBTC.owner(), address(this));
        // TransferOwnership
        vault.transferOwnership(address(1));
        rewardWBTC.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vault.initialize();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.addNewReward(address(0), address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setCurrentReward(address(0), address(0), 0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.removeReward(address(0), 0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.upgradeTo(address(0));
        // Reward
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        rewardWBTC.initialize(address(0), address(0));
        vm.expectRevert(bytes("Only vault"));
        rewardWBTC.recordDeposit(address(0), 0);
        vm.expectRevert(bytes("Only vault"));
        rewardWBTC.recordWithdraw(address(0), 0);
        vm.expectRevert(bytes("Only vault"));
        rewardWBTC.harvest(0);
        vm.expectRevert(bytes("Only claim by account or vault"));
        rewardWBTC.claim(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        rewardWBTC.setVault(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        rewardWBTC.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        rewardWBTC.setTreasury(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        rewardWBTC.upgradeTo(address(0));
    }
}

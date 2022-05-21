// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PbAvaxAnc.sol";
import "./interfaces/ITraderJoe.sol";

contract PbAvaxAncTest is Test {
    using stdStorage for StdStorage;

    PbAvaxAnc vault;
    IERC20Upgradeable rewardToken = IERC20Upgradeable(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    IERC20Upgradeable aToken = IERC20Upgradeable(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
    address treasury = 0xd924EBAF113AEBE553bC6b83AEf8f9A1B9276d57;
    IJoeRouter02 router = IJoeRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    IERC20Upgradeable WAVAX = IERC20Upgradeable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20Upgradeable UST = IERC20Upgradeable(0xb599c3590F42f8F995ECfa0f85D2980B76862fc1);
    IERC20Upgradeable aUST = IERC20Upgradeable(0xaB9A04808167C170A9EC4f8a87a0cD781ebcd55e);

    function setUp() public {
        vault = new PbAvaxAnc();
        vault.initialize(rewardToken, treasury);
    }

    receive() external payable {}

    function testDeposit() public {
        deal(address(UST), address(this), 1000e6);
        UST.approve(address(vault), type(uint).max);
        vault.deposit(UST, 1000e6, 50);

        assertEq(UST.balanceOf(address(this)), 0);
        (uint balance,, uint depositTime,) = vault.userInfo(address(this));
        assertEq(balance, 1000e6);
        assertEq(depositTime, block.timestamp);
        assertEq(vault.getAllPool(), 1000e6);
        assertEq(vault.getAllPoolInUSD(), 1000e6);
        assertEq(vault.getUserBalance(address(this)), 1000e6);
        assertEq(vault.getUserBalanceInUSD(address(this)), 1000e6);
    }

    function testDepositRevert() public {
        vm.expectRevert(bytes("Invalid token"));
        vault.deposit(WAVAX, 1000e6, 50);
        vm.expectRevert(bytes("Minimum 5 UST deposit"));
        vault.deposit(UST, 1e6, 50);
        uint slot = stdstore.target(address(vault)).sig("basePool()").find();
        vm.store(address(vault), bytes32(slot), bytes32(abi.encode(4_999_000e6)));
        vm.expectRevert(bytes("TVL max Limit reach"));
        vault.deposit(UST, 1000e6, 50);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);

        // Assume got aUST in vault
        deal(address(aUST), address(vault), 1000e6);

        // Withdraw
        vault.withdraw(UST, 1000e6, 50);
        (uint balance,,, uint pendingWithdraw) = vault.userInfo(address(this));
        assertEq(balance, 0);
        assertEq(pendingWithdraw, 998e6);
        (uint amount,,,) = vault.fees();
        assertEq(amount, 2e6);

        // Assume got UST in vault
        deal(address(UST), address(vault), 1000e6);

        // Repay withdraw
        vault.repayWithdraw(address(this));
        (,,, uint pendingWithdraw_) = vault.userInfo(address(this));
        assertEq(pendingWithdraw_, 0);
        assertEq(UST.balanceOf(address(this)), 998e6);

        // Test repay withdraw again
        vm.expectRevert(bytes("No withdrawal"));
        vault.repayWithdraw(address(this));
    }

    function testWithdrawRevert() public {
        testDeposit();
        vm.expectRevert(bytes("Invalid token"));
        vault.withdraw(WAVAX, 1000e6, 50);
        vm.expectRevert(bytes("Invalid amount to withdraw"));
        vault.withdraw(UST, 1001e6, 50);
        vm.expectRevert(bytes("Not allow withdraw within same block"));
        vault.withdraw(UST, 1000e6, 50);
    }

    function testHarvest() public {
        testDeposit();

        // Assume got aUST in vault
        deal(address(aUST), address(vault), 1000e6);

        // Initialize harvest
        vault.initializeHarvest();
        assertGt(vault.pendingHarvest(), 0);
        assertLt(aUST.balanceOf(address(vault)), 1000e6);

        // Assume done redeem UST into vault
        deal(address(UST), address(vault), 1500e6);

        // Not able to assume collect WAVAX reward from Aave

        // Harvest
        uint bef = rewardToken.balanceOf(treasury);
        vault.harvest();
        assertGt(rewardToken.balanceOf(treasury) - bef, 0);
        assertGt(vault.accRewardPerlpToken(), 0);
        assertEq(rewardToken.balanceOf(address(vault)), 0);
        assertEq(aToken.balanceOf(address(vault)), vault.lastIbRewardTokenAmt());
        assertGt(vault.getUserPendingReward(address(this)), 0);

        // Assume ibRewardToken increase
        uint bef2 = vault.accRewardPerlpToken();
        hoax(0x0fFeb87106910EEfc69c1902F411B431fFc424FF);
        aToken.transfer(address(vault), 1e16);
        vault.harvest();
        assertGt(vault.accRewardPerlpToken(), bef2);
    }

    function testClaimReward() public {
        testHarvest();
        (, uint rewardStartAtBef,,) = vault.userInfo(address(this));
        uint lastIbRewardTokenAmtBef = vault.lastIbRewardTokenAmt();
        uint aTokenBalBef = aToken.balanceOf(address(vault));
        vault.claimReward(address(this));
        (, uint rewardStartAtAft,,) = vault.userInfo(address(this));
        assertGt(rewardStartAtAft, rewardStartAtBef);
        assertLt(vault.lastIbRewardTokenAmt(), lastIbRewardTokenAmtBef);
        assertLt(aToken.balanceOf(address(vault)), aTokenBalBef);
        assertGt(rewardToken.balanceOf(address(this)), 0);
    } 

    function testClaimFees() public {
        testWithdraw();
        uint aUSTBef = aUST.balanceOf(address(vault));
        vault.claimFees();
        assertLt(aUST.balanceOf(address(vault)), aUSTBef);
        (, bool claimInProgress,,) = vault.fees();
        assertTrue(claimInProgress);

        // Try claim again
        vm.expectRevert(bytes("Claim in progress"));
        vault.claimFees();

        // Repay fees
        uint USTBef = UST.balanceOf(treasury);
        vault.repayFees();
        assertGt(UST.balanceOf(treasury), USTBef);
        (uint amount, bool claimInProgress_,,) = vault.fees();
        assertEq(amount, 0);
        assertFalse(claimInProgress_);
    }

    function testSetTVLMaxLimit() public {
        vault.setTVLMaxLimit(10_000_000e6);
        assertEq(vault.tvlMaxLimit(), 10_000_000e6);

        startHoax(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setTVLMaxLimit(5_000_000e6);
    }

    function testSetTreasury() public {
        vault.setTreasury(address(2));
        assertEq(vault.treasury(), address(2));

        startHoax(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setTreasury(address(1));
    }

    function testPause() public {
        vault.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(UST, 1000e6, 50);
        vault.unpauseContract();
        testDeposit();

        startHoax(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.unpauseContract();
    }
}

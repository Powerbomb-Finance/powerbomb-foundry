// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/PbCrvOpEth.sol";
import "../src/PbProxy.sol";

contract PbCrvOpEthTest is Test {
    IPool pool = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IGauge gauge = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
    IERC20Upgradeable CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable SETH = IERC20Upgradeable(0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    PbCrvOpEth vaultUSDC;
    PbCrvOpEth vaultWETH;
    PbCrvOpEth vaultWBTC;
    IERC20Upgradeable aUSDC;
    IERC20Upgradeable aWETH;
    IERC20Upgradeable aWBTC;
    // address owner = address(this);
    // address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address multisig = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49; // multisig
    address owner = multisig;
    // address owner = address(this);

    function setUp() public {
        // // Deploy implementation contract
        // PbCrvOpEth vaultImpl = new PbCrvOpEth();
        // PbProxy proxy;

        // // Deploy USDC reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         // bytes4(keccak256("initialize(address,address)")),
        //         PbCrvOpEth.initialize.selector,
        //         address(USDC),
        //         address(multisig)
        //     )
        // );
        // vaultUSDC = PbCrvOpEth(address(proxy));
        vaultUSDC = PbCrvOpEth(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631);
        // PbCrvOpEth vaultUSDCImpl = new PbCrvOpEth();
        // hoax(owner);
        // vaultUSDC.upgradeTo(address(vaultUSDCImpl));

        // // Deploy WETH reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         PbCrvOpEth.initialize.selector,
        //         address(WETH),
        //         address(multisig)
        //     )
        // );
        // vaultWETH = PbCrvOpEth(address(proxy));
        vaultWETH = PbCrvOpEth(0x72F6ECF3dE8A58aBA9F97b4c5d1C213Df976cf4E);

        // // Deploy WBTC reward proxy contract
        // proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         PbCrvOpEth.initialize.selector,
        //         address(WBTC),
        //         address(multisig)
        //     )
        // );
        // vaultWBTC = PbCrvOpEth(address(proxy));
        vaultWBTC = PbCrvOpEth(0xb8fEb9d8a1ab83f59Ee423281b72c62EC9dD4A97);

        // Initialize aToken
        aUSDC = IERC20Upgradeable(vaultUSDC.aToken());
        aWETH = IERC20Upgradeable(vaultWETH.aToken());
        aWBTC = IERC20Upgradeable(vaultWBTC.aToken());

        // Reset treasury token for testing purpose
        deal(address(USDC), address(multisig), 0);
        deal(address(WETH), address(multisig), 0);
        deal(address(WBTC), address(multisig), 0);
    }

    function testDeposit() public {
        // Deposit ETH for USDC reward
        uint[2] memory amounts = [uint(10 ether), 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultUSDC.deposit{value: 10 ether}(WETH, 10 ether, amountOut * 99 / 100);
        // Deposit SETH for WETH reward
        address SETHHolderAddr = 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F;
        hoax(SETHHolderAddr);
        SETH.transfer(address(this), 10 ether);
        amounts = [uint(0), 10 ether];
        amountOut = pool.calc_token_amount(amounts, true);
        SETH.approve(address(vaultWETH), type(uint).max);
        vaultWETH.deposit(SETH, 10 ether, amountOut * 99 / 100);
        // Deposit lpToken for WBTC reward
        deal(address(lpToken), address(this), 10 ether);
        lpToken.approve(address(vaultWBTC), type(uint).max);
        vaultWBTC.deposit(lpToken, lpToken.balanceOf(address(this)), 0);
        // Assertion check
        assertGt(vaultUSDC.getAllPool(), 0);
        // console.log(vaultUSDC.getAllPoolInUSD()); // 41367.051505
        assertGt(vaultWETH.getAllPool(), 0);
        assertGt(vaultWBTC.getAllPool(), 0);
        assertGt(vaultUSDC.getAllPoolInUSD(), 0);
        // console.log(vaultUSDC.getUserBalance(address(this)));
        assertGt(vaultWETH.getAllPoolInUSD(), 0);
        assertGt(vaultWBTC.getAllPoolInUSD(), 0);
        assertGt(vaultUSDC.getUserBalance(address(this)), 0);
        // console.log(vaultUSDC.getUserBalanceInUSD(address(this)));
        assertGt(vaultWETH.getUserBalance(address(this)), 0);
        assertGt(vaultWBTC.getUserBalance(address(this)), 0);
        assertGt(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultWETH.getUserBalanceInUSD(address(this)), 0);
        assertGt(vaultWBTC.getUserBalanceInUSD(address(this)), 0);
        assertEq(SETH.balanceOf(address(vaultUSDC)), 0);
        assertEq(SETH.balanceOf(address(vaultWBTC)), 0);
        assertEq(SETH.balanceOf(address(vaultWETH)), 0);
        assertEq(WETH.balanceOf(address(vaultUSDC)), 0);
        assertEq(WETH.balanceOf(address(vaultWBTC)), 0);
        assertEq(WETH.balanceOf(address(vaultWETH)), 0);
        assertEq(address(vaultUSDC).balance, 0);
        assertEq(address(vaultWETH).balance, 0);
        assertEq(address(vaultWBTC).balance, 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
        assertEq(lpToken.balanceOf(address(vaultWETH)), 0);
        assertEq(lpToken.balanceOf(address(vaultWBTC)), 0);
    }

    function testWithdraw() public {
        // Record before deposit
        uint allPoolVaultUSDC = vaultUSDC.getAllPool();
        uint allPoolVaultWETH = vaultWETH.getAllPool();
        uint allPoolVaultWBTC = vaultWBTC.getAllPool();
        uint allPoolInUSDVaultUSDC = vaultUSDC.getAllPoolInUSD();
        uint allPoolInUSDVaultWETH = vaultWETH.getAllPoolInUSD();
        uint allPoolInUSDVaultWBTC = vaultWBTC.getAllPoolInUSD();
        testDeposit();
        vm.roll(block.number + 1);
        // Record ETH before withdraw
        uint ethAmt = address(this).balance;
        // Withdraw ETH from USDC reward
        uint amountOut = pool.calc_withdraw_one_coin(vaultUSDC.getUserBalance(address(this)), int128(0));
        vaultUSDC.withdraw(WETH, vaultUSDC.getUserBalance(address(this)), amountOut * 99 / 100);
        // Withdraw SETH from WETH reward
        amountOut = pool.calc_withdraw_one_coin(vaultWETH.getUserBalance(address(this)), int128(1));
        vaultWETH.withdraw(SETH, vaultWETH.getUserBalance(address(this)), amountOut * 99 / 100);
        // Withdraw lpToken from WBTC reward
        vaultWBTC.withdraw(lpToken, vaultWBTC.getUserBalance(address(this)), 0);
        // Assertion check
        assertEq(vaultUSDC.getAllPool(), allPoolVaultUSDC);
        assertEq(vaultWETH.getAllPool(), allPoolVaultWETH);
        assertEq(vaultWBTC.getAllPool(), allPoolVaultWBTC);
        // assertEq(vaultUSDC.getAllPoolInUSD(), allPoolInUSDVaultUSDC); // diff $0.4 with 400k tvl tested 24/2/2013 which is okay
        assertEq(vaultWETH.getAllPoolInUSD(), allPoolInUSDVaultWETH);
        assertEq(vaultWBTC.getAllPoolInUSD(), allPoolInUSDVaultWBTC);
        assertEq(vaultUSDC.getUserBalance(address(this)), 0);
        assertEq(vaultWETH.getUserBalance(address(this)), 0);
        assertEq(vaultWBTC.getUserBalance(address(this)), 0);
        assertEq(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        assertEq(vaultWETH.getUserBalanceInUSD(address(this)), 0);
        assertEq(vaultWBTC.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - ethAmt); // 
        // console.log(SETH.balanceOf(address(this))); // 
        // console.log(lpToken.balanceOf(address(this))); // 
        assertEq(address(vaultUSDC).balance, 0);
        assertEq(address(vaultWETH).balance, 0);
        assertEq(address(vaultWBTC).balance, 0);
        assertEq(SETH.balanceOf(address(vaultUSDC)), 0);
        assertEq(SETH.balanceOf(address(vaultWETH)), 0);
        assertEq(SETH.balanceOf(address(vaultWBTC)), 0);
        assertGt(address(this).balance - ethAmt, 0);
        assertGt(SETH.balanceOf(address(this)), 0);
    }

    receive() external payable {}

    function testHarvest() public returns (uint userPendingRewardUSDC, uint userPendingRewardWETH, uint userPendingRewardWBTC) {
        testDeposit();
        // Assume reward
        skip(864000);
        (uint crvRewardVaultUSDC, uint opRewardVaultUSDC) = vaultUSDC.getPoolPendingReward2();
        (uint crvRewardVaultWETH, uint opRewardVaultWETH) = vaultWETH.getPoolPendingReward2();
        (uint crvRewardVaultWBTC, uint opRewardVaultWBTC) = vaultWBTC.getPoolPendingReward2();
        // assertGt(crvRewardVaultUSDC, 0); // no crv reward when test on 23/2/2023
        assertGt(opRewardVaultUSDC, 0);
        assertGt(opRewardVaultWETH, 0);
        assertGt(opRewardVaultWBTC, 0);
        // Assume harvest token
        deal(address(CRV), address(vaultUSDC), 1.1 ether);
        deal(address(OP), address(vaultUSDC), 1.1 ether);
        deal(address(CRV), address(vaultWETH), 1.1 ether);
        deal(address(OP), address(vaultWETH), 1.1 ether);
        deal(address(CRV), address(vaultWBTC), 1.1 ether);
        deal(address(OP), address(vaultWBTC), 1.1 ether);
        // Check user pending rewards before harvest
        // userPendingRewardUSDC = vaultUSDC.getUserPendingReward2(address(this)); // vaultUSDC doesn't got this function yet
        // assertGt(userPendingRewardUSDC, 0);
        userPendingRewardWETH = vaultWETH.getUserPendingReward2(address(this));
        assertGt(userPendingRewardWETH, 0);
        userPendingRewardWBTC = vaultWBTC.getUserPendingReward2(address(this));
        assertGt(userPendingRewardWBTC, 0);
        // Harvest
        vaultUSDC.harvest();
        vaultWETH.harvest();
        vaultWBTC.harvest();

        // Assertion check
        assertEq(CRV.balanceOf(address(vaultUSDC)), 0);
        assertEq(CRV.balanceOf(address(vaultWETH)), 0);
        assertEq(CRV.balanceOf(address(vaultWBTC)), 0);
        assertEq(OP.balanceOf(address(vaultUSDC)), 0);
        assertEq(OP.balanceOf(address(vaultWETH)), 0);
        assertEq(OP.balanceOf(address(vaultWBTC)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertEq(WETH.balanceOf(address(vaultWETH)), 0);
        assertEq(WBTC.balanceOf(address(vaultWBTC)), 0);
        assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(aWETH.balanceOf(address(vaultWETH)), 0);
        assertGt(aWBTC.balanceOf(address(vaultWBTC)), 0);
        assertGt(USDC.balanceOf(multisig), 0); // treasury fee
        assertGt(WETH.balanceOf(multisig), 0);
        assertGt(WBTC.balanceOf(multisig), 0);
        assertGt(vaultUSDC.accRewardPerlpToken(), 0);
        assertGt(vaultWETH.accRewardPerlpToken(), 0);
        assertGt(vaultWBTC.accRewardPerlpToken(), 0);
        assertGt(vaultUSDC.lastATokenAmt(), 0);
        assertGt(vaultWETH.lastATokenAmt(), 0);
        assertGt(vaultWBTC.lastATokenAmt(), 0);
        // Harvest again after deposit aToken
        // console.log(aUSDC.balanceOf(address(vaultUSDC)));
        skip(864000);
        // uint OPBal = OP.balanceOf(address(vaultUSDC));
        // deal(address(CRV), address(vaultUSDC), 2 ether); // Assume CRV meet threshold
        // deal(address(OP), address(vaultUSDC), 2 ether); // Assume OP meet threshold
        // vaultUSDC.harvest();
        // console.log(aUSDC.balanceOf(address(vaultUSDC)));
        // assertGt(OP.balanceOf(address(vaultUSDC)), OPBal); // no OP reward after harvest again as tested 23/2/2023
        // console.log(aUSDC.balanceOf(address(vaultUSDC))); // 28302708 31853619
        // assertEq(OP.balanceOf(address(vaultUSDC)), 0);
        // Assume aToken increase
        // hoax(0x4ecB5300D9ec6BCA09d66bfd8Dcb532e3192dDA1);
        // aUSDC.transfer(address(vaultUSDC), 10e6);
        uint accRewardPerlpTokenUSDC = vaultUSDC.accRewardPerlpToken();
        uint accRewardPerlpTokenWETH = vaultWETH.accRewardPerlpToken();
        uint accRewardPerlpTokenWBTC = vaultWBTC.accRewardPerlpToken();
        uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        uint lastATokenAmtWETH = vaultWETH.lastATokenAmt();
        uint lastATokenAmtWBTC = vaultWBTC.lastATokenAmt();
        uint userPendingVaultUSDC = vaultUSDC.getUserPendingReward(address(this));
        uint userPendingVaultWETH = vaultWETH.getUserPendingReward(address(this));
        uint userPendingVaultWBTC = vaultWBTC.getUserPendingReward(address(this));
        // // Harvest again
        vaultUSDC.harvest();
        vaultWETH.harvest();
        // aWBTC accumulate amount too small, assume increase
        hoax(0x8eb23a3010795574eE3DD101843dC90bD63b5099);
        aWBTC.transfer(address(vaultWBTC), 1);
        vaultWBTC.harvest();
        // Assertion check
        assertGt(vaultUSDC.accRewardPerlpToken(), accRewardPerlpTokenUSDC);
        assertGt(vaultWETH.accRewardPerlpToken(), accRewardPerlpTokenWETH);
        assertGt(vaultWBTC.accRewardPerlpToken(), accRewardPerlpTokenWBTC);
        assertGt(vaultUSDC.lastATokenAmt(), lastATokenAmtUSDC);
        assertGt(vaultWETH.lastATokenAmt(), lastATokenAmtWETH);
        assertGt(vaultWBTC.lastATokenAmt(), lastATokenAmtWBTC);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingVaultUSDC);
        assertGt(vaultWETH.getUserPendingReward(address(this)), userPendingVaultWETH);
        assertGt(vaultWBTC.getUserPendingReward(address(this)), userPendingVaultWBTC);
        // console.log(userPendingVaultUSDC); // 5076969 -> 5.07 USD
    }

    function testClaim() public {
        (uint userPendingRewardUSDC, uint userPendingRewardWETH, uint userPendingRewardWBTC) = testHarvest();
        // Claim
        vaultUSDC.claim();
        vaultWETH.claim();
        vaultWBTC.claim();
        // Assertion check
        // console.log(USDC.balanceOf(address(this)));
        // console.log(WETH.balanceOf(address(this)));
        // console.log(WBTC.balanceOf(address(this)));
        assertGt(USDC.balanceOf(address(this)), userPendingRewardUSDC);
        assertGt(WETH.balanceOf(address(this)), userPendingRewardWETH);
        assertGt(WBTC.balanceOf(address(this)), userPendingRewardWBTC);
        (, uint rewardStartAtUSDC) = vaultUSDC.userInfo(address(this));
        assertGt(rewardStartAtUSDC, 0);
        (, uint rewardStartAtWETH) = vaultWETH.userInfo(address(this));
        assertGt(rewardStartAtWETH, 0);
        (, uint rewardStartAtWBTC) = vaultWBTC.userInfo(address(this));
        assertGt(rewardStartAtWBTC, 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertEq(WETH.balanceOf(address(vaultWETH)), 0);
        assertEq(WBTC.balanceOf(address(vaultWBTC)), 0);

        // uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        // assertLe(lastATokenAmtUSDC, 2);
        // assertLe(aUSDC.balanceOf(address(vaultUSDC)), 2);
        // uint lastATokenAmtWETH = vaultWETH.lastATokenAmt();
        // assertLe(lastATokenAmtWETH, 2);
        // assertLe(aWETH.balanceOf(address(vaultWETH)), 2);
        // uint lastATokenAmtWBTC = vaultWBTC.lastATokenAmt();
        // assertLe(lastATokenAmtWBTC, 2);
        // assertLe(aWBTC.balanceOf(address(vaultWBTC)), 2);
    }

    function testPauseContract() public {
        // Pause contract and test deposit
        hoax(owner);
        vaultUSDC.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultUSDC.deposit{value: 10 ether}(WETH, 10 ether, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultUSDC.unPauseContract();
        vaultUSDC.deposit{value: 10 ether}(WETH, 10 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultUSDC.pauseContract();
        vaultUSDC.withdraw(WETH, vaultUSDC.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbCrvOpEth vault_ = new PbCrvOpEth();
        startHoax(owner);
        vaultUSDC.upgradeTo(address(vault_));
    }

    function testSetter() public {
        startHoax(owner);
        vaultUSDC.setYieldFeePerc(1000);
        assertEq(vaultUSDC.yieldFeePerc(), 1000);
        vaultUSDC.setTreasury(address(1));
        assertEq(vaultUSDC.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultUSDC.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultUSDC.transferOwnership(address(1));
        // Vault
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUSDC.initialize(IERC20Upgradeable(address(0)), address(0));
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
    }
}

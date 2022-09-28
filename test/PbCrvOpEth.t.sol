// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/PbCrvOpEth.sol";
import "../src/PbProxy.sol";

contract PbCrvOpEthTest is Test {
    IPool pool = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IGauge gauge = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
    IERC20Upgradeable CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable SETH = IERC20Upgradeable(0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IERC20Upgradeable OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    PbCrvOpEth vaultUSDC;
    IERC20Upgradeable aUSDC;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    // address owner = address(this);

    function setUp() public {
        // // Deploy implementation contract
        // PbCrvOpEth vaultImpl = new PbCrvOpEth();

        // // Deploy USDC reward proxy contract
        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(USDC),
        //         address(6288)
        //     )
        // );
        // vaultUSDC = PbCrvOpEth(address(proxy));
        vaultUSDC = PbCrvOpEth(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631);
        PbCrvOpEth vaultUSDCImpl = new PbCrvOpEth();
        // hoax(owner);
        // vaultUSDC.upgradeTo(address(vaultUSDCImpl));

        // Initialize aToken
        aUSDC = IERC20Upgradeable(vaultUSDC.aToken());

        // Reset treasury token for testing purpose
        deal(address(USDC), address(owner), 0);
    }

    function testDeposit() public {
        // Deposit ETH for USDC reward
        uint[2] memory amounts = [uint(10 ether), 0];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultUSDC.deposit{value: 10 ether}(WETH, 10 ether, amountOut * 99 / 100);
        // Deposit SETH for USDC reward
        // deal(address(SETH), address(this), 10000 ether);
        address SETHHolderAddr = 0x12478d1a60a910C9CbFFb90648766a2bDD5918f5;
        hoax(SETHHolderAddr);
        SETH.transfer(address(this), 10 ether);
        SETH.approve(address(vaultUSDC), type(uint).max);
        amounts = [0, SETH.balanceOf(address(this))];
        amountOut = pool.calc_token_amount(amounts, true);
        vaultUSDC.deposit(SETH, SETH.balanceOf(address(this)), amountOut * 99 / 100);
        // Deposit lpToken for USDC reward
        deal(address(lpToken), address(this), 10 ether);
        lpToken.approve(address(vaultUSDC), type(uint).max);
        vaultUSDC.deposit(lpToken, lpToken.balanceOf(address(this)), 0);
        // Assertion check
        // console.log(vaultUSDC.getAllPool()); // 29.982668032552650363
        assertGt(vaultUSDC.getAllPool(), 0);
        // console.log(vaultUSDC.getAllPoolInUSD()); // 41367.051505
        assertGt(vaultUSDC.getAllPoolInUSD(), 0);
        // console.log(vaultUSDC.getUserBalance(address(this)));
        assertGt(vaultUSDC.getUserBalance(address(this)), 0);
        // console.log(vaultUSDC.getUserBalanceInUSD(address(this)));
        assertGt(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        assertEq(SETH.balanceOf(address(vaultUSDC)), 0);
        assertEq(WETH.balanceOf(address(vaultUSDC)), 0);
        assertEq(address(vaultUSDC).balance, 0);
        assertEq(lpToken.balanceOf(address(vaultUSDC)), 0);
    }

    function testWithdraw() public {
        // Record before deposit
        uint allPool = vaultUSDC.getAllPool();
        uint allPoolInUSD = vaultUSDC.getAllPoolInUSD();
        testDeposit();
        vm.roll(block.number + 1);
        // Record ETH before withdraw
        uint ethAmt = address(this).balance;
        // Withdraw ETH from USDC reward
        uint amountOut = pool.calc_withdraw_one_coin(vaultUSDC.getUserBalance(address(this)) / 3, int128(0));
        vaultUSDC.withdraw(WETH, vaultUSDC.getUserBalance(address(this)) / 3, amountOut * 99 / 100);
        // Withdraw SETH from WETH reward
        amountOut = pool.calc_withdraw_one_coin(vaultUSDC.getUserBalance(address(this)) / 2, int128(1));
        vaultUSDC.withdraw(SETH, vaultUSDC.getUserBalance(address(this)) / 2, amountOut * 99 / 100);
        // Withdraw lpToken from WETH reward
        vaultUSDC.withdraw(lpToken, vaultUSDC.getUserBalance(address(this)), 0);
        // Assertion check
        assertEq(vaultUSDC.getAllPool(), allPool);
        assertEq(vaultUSDC.getAllPoolInUSD(), allPoolInUSD);
        assertEq(vaultUSDC.getUserBalance(address(this)), 0);
        assertEq(vaultUSDC.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - ethAmt); // 
        // console.log(SETH.balanceOf(address(this))); // 
        // console.log(lpToken.balanceOf(address(this))); // 
        assertEq(address(vaultUSDC).balance, 0);
        assertEq(SETH.balanceOf(address(vaultUSDC)), 0);
        assertGt(address(this).balance - ethAmt, 0);
        assertGt(SETH.balanceOf(address(this)), 0);
    }

    receive() external payable {}

    function testHarvest() public {
        testDeposit();
        // Assume reward
        skip(864000);
        (uint crvReward, uint opReward) = vaultUSDC.getPoolPendingReward2();
        assertGt(crvReward, 0);
        assertGt(opReward, 0);
        // Harvest USDC reward
        deal(address(CRV), address(vaultUSDC), 1 ether);
        vaultUSDC.harvest();
        // Assertion check
        assertEq(CRV.balanceOf(address(vaultUSDC)), 0);
        assertEq(OP.balanceOf(address(vaultUSDC)), 0);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(aUSDC.balanceOf(address(vaultUSDC)), 0);
        assertGt(USDC.balanceOf(owner), 0); // treasury fee
        assertGt(vaultUSDC.accRewardPerlpToken(), 0);
        assertGt(vaultUSDC.lastATokenAmt(), 0);
        // Harvest again after deposit aToken
        skip(864000);
        uint OPBal = OP.balanceOf(address(vaultUSDC));
        // deal(address(CRV), address(vaultUSDC), 2 ether); // Assume CRV meet threshold
        // deal(address(OP), address(vaultUSDC), 2 ether); // Assume OP meet threshold
        vaultUSDC.harvest();
        assertGt(OP.balanceOf(address(vaultUSDC)), OPBal);
        // console.log(aUSDC.balanceOf(address(vaultUSDC))); // 28302708 31853619
        // assertEq(OP.balanceOf(address(vaultUSDC)), 0);
        // Assume aToken increase
        hoax(0x70144e5b5bbf464cFf98d689254dc7C7223E01Ab);
        aUSDC.transfer(address(vaultUSDC), 10e6);
        uint accRewardPerlpTokenUSDC = vaultUSDC.accRewardPerlpToken();
        uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        uint userPendingVaultUSDC = vaultUSDC.getUserPendingReward(address(this));
        // Harvest again
        vaultUSDC.harvest();
        // Assertion check
        assertGt(vaultUSDC.accRewardPerlpToken(), accRewardPerlpTokenUSDC);
        assertGt(vaultUSDC.lastATokenAmt(), lastATokenAmtUSDC);
        assertGt(vaultUSDC.getUserPendingReward(address(this)), userPendingVaultUSDC);
        // console.log(userPendingVaultUSDC); // 5076969 -> 5.07 USD
    }

    function testClaim() public {
        testHarvest();
        // Record variable before claim
        uint userPendingRewardUSDC = vaultUSDC.getUserPendingReward(address(this));
        // Claim
        vaultUSDC.claim();
        // Assertion check
        assertGt(USDC.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), userPendingRewardUSDC);
        (, uint rewardStartAtUSDC) = vaultUSDC.userInfo(address(this));
        assertGt(rewardStartAtUSDC, 0);
        // uint lastATokenAmtUSDC = vaultUSDC.lastATokenAmt();
        // assertLe(lastATokenAmtUSDC, 2);
        // assertLe(aUSDC.balanceOf(address(vaultUSDC)), 2);
        assertEq(USDC.balanceOf(address(vaultUSDC)), 0);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbCvxCrv.sol";
import "../interface/IPool.sol";
import "../interface/IZap.sol";

contract PbCvxCrvTest is Test {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable crv = IERC20Upgradeable(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Upgradeable cvx = IERC20Upgradeable(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    PbCvxCrv vaultWbtc;
    PbCvxCrv vaultWeth;
    PbCvxCrv vaultUsdc;
    IPool pool = IPool(0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511);
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWbtc = IERC20Upgradeable(0x13B2f6928D7204328b0E8E4BCd0379aA06EA21FA);
    IERC20Upgradeable aWeth = IERC20Upgradeable(0xf9Fb4AD91812b704Ba883B11d2B576E890a6730A);
    IERC20Upgradeable aUsdc = IERC20Upgradeable(0xd24946147829DEaA935bE2aD85A3291dbf109c80);
    address owner = address(this);

    function setUp() public {
        // Deploy implementation contract
        PbCvxCrv vaultImpl = new PbCvxCrv();
        PbProxy proxy;
        uint pid = 61;

        // Deploy wbtc reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address,address)")),
                pid,
                address(pool),
                address(wbtc)
            )
        );
        vaultWbtc = PbCvxCrv(payable(address(proxy)));

        // Deploy weth reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address,address)")),
                pid,
                address(pool),
                address(weth)
            )
        );
        vaultWeth = PbCvxCrv(payable(address(proxy)));

        // Deploy usdc reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address,address)")),
                pid,
                address(pool),
                address(usdc)
            )
        );
        vaultUsdc = PbCvxCrv(payable(address(proxy)));

        lpToken = vaultWbtc.lpToken();
    }

    // function test() public {
    //     vaultWbtc.deposit{value: 10 ether}(weth, 10 ether, 0);
    //     deal(address(crv), address(this), 10000 ether);
    //     crv.approve(address(vaultWeth), type(uint).max);
    //     vaultWeth.deposit(crv, 10000 ether, 0);
    //     deal(address(lpToken), address(this), 1000 ether);
    //     lpToken.approve(address(vaultUsdc), type(uint).max);
    //     vaultUsdc.deposit(lpToken, 1000 ether, 0);
    //     // console.log(vaultWbtc.getAllPoolInUSD());
    //     // console.log(vaultWeth.getAllPoolInUSD());
    //     // console.log(vaultUsdc.getAllPoolInUSD());

    //     skip(864000);
    //     // (uint pendingCrv, uint pendingCvx) = vaultWbtc.getPoolPendingReward();
    //     // console.log(pendingCrv);
    //     // console.log(pendingCvx);
    //     // pendingCvx = vaultWbtc.getPoolExtraPendingReward();
    //     // console.log(pendingCvx);
    //     deal(address(crv), address(vaultWbtc), 1.1 ether);
    //     deal(address(cvx), address(vaultWbtc), 1.1 ether);
    //     deal(address(crv), address(vaultWeth), 1.1 ether);
    //     deal(address(cvx), address(vaultWeth), 1.1 ether);
    //     deal(address(crv), address(vaultUsdc), 1.1 ether);
    //     deal(address(cvx), address(vaultUsdc), 1.1 ether);
    //     vaultWbtc.harvest();
    //     vaultWeth.harvest();
    //     vaultUsdc.harvest();
    //     console.log(aWbtc.balanceOf(address(vaultWbtc)));
    //     console.log(aWeth.balanceOf(address(vaultWeth)));
    //     console.log(aUsdc.balanceOf(address(vaultUsdc)));
    //     vaultWbtc.claim();

    //     vm.roll(block.number + 1);
    //     // uint balBef = address(this).balance;
    //     vaultWbtc.withdraw(weth, vaultWbtc.getUserBalance(address(this)), 0);
    //     vaultWeth.withdraw(crv, vaultWeth.getUserBalance(address(this)), 0);
    //     vaultUsdc.withdraw(lpToken, vaultUsdc.getUserBalance(address(this)), 0);
    //     // console.log(address(this).balance - balBef);
    //     // console.log(crv.balanceOf(address(this)));
    //     // console.log(lpToken.balanceOf(address(this)));
    // }

    function testDeposit() public {
        uint[2] memory amounts;
        uint amountOut;

        // deposit weth into vaultWbtc
        amounts = [10 ether, uint(0)];
        amountOut = pool.calc_token_amount(amounts);
        // console.log(amountOut);
        vaultWbtc.deposit{value: 10 ether}(weth, 10 ether, amountOut * 99 / 100);
        // console.log(vaultWbtc.getAllPool());

        // deposit crv into vaultWeth
        deal(address(crv), address(this), 10000 ether);
        crv.approve(address(vaultWeth), type(uint).max);
        amounts = [uint(0), 10000 ether];
        amountOut = pool.calc_token_amount(amounts);
        // console.log(amountOut);
        vaultWeth.deposit(crv, 10000 ether, amountOut * 99 / 100);
        // console.log(vaultWeth.getAllPool());

        // deposit lp token into vaultUsdc
        deal(address(lpToken), address(this), 1000 ether);
        lpToken.approve(address(vaultUsdc), type(uint).max);
        vaultUsdc.deposit(lpToken, 1000 ether, 0);

        // assertion check
        // vaultWbtc
        // console.log(vaultWbtc.getAllPool());
        assertGt(vaultWbtc.getAllPool(), 0);
        // console.log(vaultWbtc.getAllPoolInUSD());
        assertGt(vaultWbtc.getAllPoolInUSD(), 0);
        // console.log(vaultWbtc.getUserBalance(address(this)));
        assertGt(vaultWbtc.getUserBalance(address(this)), 0);
        // console.log(vaultWbtc.getUserBalanceInUSD(address(this)));
        assertGt(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        assertEq(address(vaultWbtc).balance, 0);
        assertEq(crv.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);

        // vaultWeth
        // console.log(vaultWeth.getAllPool());
        assertGt(vaultWeth.getAllPool(), 0);
        // console.log(vaultWeth.getAllPoolInUSD());
        assertGt(vaultWeth.getAllPoolInUSD(), 0);
        // console.log(vaultWeth.getUserBalance(address(this)));
        assertGt(vaultWeth.getUserBalance(address(this)), 0);
        // console.log(vaultWeth.getUserBalanceInUSD(address(this)));
        assertGt(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        assertEq(address(vaultWeth).balance, 0);
        assertEq(crv.balanceOf(address(vaultWeth)), 0);
        assertEq(lpToken.balanceOf(address(vaultWeth)), 0);

        // vaultUsdc
        // console.log(vaultUsdc.getAllPool());
        assertGt(vaultUsdc.getAllPool(), 0);
        // console.log(vaultUsdc.getAllPoolInUSD());
        assertGt(vaultUsdc.getAllPoolInUSD(), 0);
        // console.log(vaultUsdc.getUserBalance(address(this)));
        assertGt(vaultUsdc.getUserBalance(address(this)), 0);
        // console.log(vaultUsdc.getUserBalanceInUSD(address(this)));
        assertGt(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(crv.balanceOf(address(vaultUsdc)), 0);
        assertEq(lpToken.balanceOf(address(vaultUsdc)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint amountOut;

        // withdraw eth from vaultWbtc
        uint balBef = address(this).balance;
        amountOut = pool.calc_withdraw_one_coin(vaultWbtc.getUserBalance(address(this)), uint(0));
        // console.log(amountOut);
        vaultWbtc.withdraw(weth, vaultWbtc.getUserBalance(address(this)), amountOut * 99 / 100);

        // withdraw crv from vaultWeth
        amountOut = pool.calc_withdraw_one_coin(vaultWeth.getUserBalance(address(this)), uint(1));
        // console.log(amountOut);
        vaultWeth.withdraw(crv, vaultWeth.getUserBalance(address(this)), amountOut * 99 / 100);

        // withdraw lp token from vaultUSdc
        vaultUsdc.withdraw(lpToken, vaultUsdc.getUserBalance(address(this)), 0);

        uint lpTokenAmt;
        uint rewardStartAt;
        // assertion check
        // vaultWbtc
        assertEq(vaultWbtc.getAllPool(), 0);
        assertEq(vaultWbtc.getAllPoolInUSD(), 0);
        assertEq(vaultWbtc.getUserBalance(address(this)), 0);
        assertEq(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - balBef);
        assertGt(address(this).balance - balBef, 0);
        assertEq(address(vaultWbtc).balance, 0);
        assertEq(crv.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);
        (lpTokenAmt, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultWeth
        assertEq(vaultWeth.getAllPool(), 0);
        assertEq(vaultWeth.getAllPoolInUSD(), 0);
        assertEq(vaultWeth.getUserBalance(address(this)), 0);
        assertEq(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        // console.log(crv.balanceOf(address(this)));
        assertGt(crv.balanceOf(address(this)), 0);
        assertEq(address(vaultWeth).balance, 0);
        assertEq(crv.balanceOf(address(vaultWeth)), 0);
        assertEq(lpToken.balanceOf(address(vaultWeth)), 0);
        (lpTokenAmt, rewardStartAt) = vaultWeth.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultUsdc
        assertEq(vaultUsdc.getAllPool(), 0);
        assertEq(vaultUsdc.getAllPoolInUSD(), 0);
        assertEq(vaultUsdc.getUserBalance(address(this)), 0);
        assertEq(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(crv.balanceOf(address(vaultUsdc)), 0);
        assertEq(lpToken.balanceOf(address(vaultUsdc)), 0);
        (lpTokenAmt, rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);

        uint crvReward;
        uint cvxReward;
        uint extraCvxReward;
        // check pending reward
        // vaultWbtc
        (crvReward, cvxReward) = vaultWbtc.getPoolPendingReward();
        (extraCvxReward) = vaultWbtc.getPoolExtraPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        // console.log(extraCvxReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0);
        assertEq(extraCvxReward, 0); // no cvx reward at the moment

        // vaultWeth
        (crvReward, cvxReward) = vaultWeth.getPoolPendingReward();
        (extraCvxReward) = vaultWeth.getPoolExtraPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        // console.log(extraCvxReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0); 
        assertEq(extraCvxReward, 0);

        // vaultUsdc
        (crvReward, cvxReward) = vaultUsdc.getPoolPendingReward();
        (extraCvxReward) = vaultUsdc.getPoolExtraPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        // console.log(extraCvxReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0); 
        assertEq(extraCvxReward, 0);

        // assume crv & cvx > 1 ether
        deal(address(crv), address(vaultWbtc), 1.1 ether);
        deal(address(cvx), address(vaultWbtc), 1.1 ether);
        deal(address(crv), address(vaultWeth), 1.1 ether);
        deal(address(cvx), address(vaultWeth), 1.1 ether);
        deal(address(crv), address(vaultUsdc), 1.1 ether);
        deal(address(cvx), address(vaultUsdc), 1.1 ether);

        // harvest
        vaultWbtc.harvest();
        vaultWeth.harvest();
        vaultUsdc.harvest();

        uint accRewardPerlpToken;
        uint lastATokenAmt;
        uint userPendingVault;
        // assertion check
        // vaultWbtc
        assertEq(crv.balanceOf(address(vaultWbtc)), 0);
        assertEq(cvx.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertGt(aWbtc.balanceOf(address(vaultWbtc)), 0);
        assertGt(vaultWbtc.accRewardPerlpToken(), 0);
        assertGt(vaultWbtc.lastATokenAmt(), 0);
        assertGt(vaultWbtc.accRewardTokenAmt(), 0);
        // console.log(vaultWbtc.getUserPendingReward(address(this)));
        assertGt(vaultWbtc.getUserPendingReward(address(this)), 0);
        // Assume aWbtc increase
        hoax(0xB58163D9148EfFEdF4eF8517Ad1D3251b1ddD837);
        aWbtc.transfer(address(vaultWbtc), 1e5);
        accRewardPerlpToken = vaultWbtc.accRewardPerlpToken();
        lastATokenAmt = vaultWbtc.lastATokenAmt();
        userPendingVault = vaultWbtc.getUserPendingReward(address(this));
        vaultWbtc.harvest();
        assertGt(vaultWbtc.accRewardPerlpToken(), accRewardPerlpToken);
        assertGt(vaultWbtc.lastATokenAmt(), lastATokenAmt);
        assertGt(vaultWbtc.getUserPendingReward(address(this)), userPendingVault);

        // vaultWeth
        assertEq(crv.balanceOf(address(vaultWeth)), 0);
        assertEq(cvx.balanceOf(address(vaultWeth)), 0);
        assertEq(usdc.balanceOf(address(vaultWeth)), 0);
        assertGt(aWeth.balanceOf(address(vaultWeth)), 0);
        assertGt(vaultWeth.accRewardPerlpToken(), 0);
        assertGt(vaultWeth.lastATokenAmt(), 0);
        assertGt(vaultWeth.accRewardTokenAmt(), 0);
        // console.log(vaultWeth.getUserPendingReward(address(this)));
        assertGt(vaultWeth.getUserPendingReward(address(this)), 0);
        // Assume aWeth increase
        hoax(0x751AE03B6f59A2cc3c58845219D4D1368C37880b);
        aWeth.transfer(address(vaultWeth), 1e15);
        accRewardPerlpToken = vaultWeth.accRewardPerlpToken();
        lastATokenAmt = vaultWeth.lastATokenAmt();
        userPendingVault = vaultWeth.getUserPendingReward(address(this));
        vaultWeth.harvest();
        assertGt(vaultWeth.accRewardPerlpToken(), accRewardPerlpToken);
        assertGt(vaultWeth.lastATokenAmt(), lastATokenAmt);
        assertGt(vaultWeth.getUserPendingReward(address(this)), userPendingVault);

        // vaultUsdc
        assertEq(crv.balanceOf(address(vaultUsdc)), 0);
        assertEq(cvx.balanceOf(address(vaultUsdc)), 0);
        assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
        assertGt(aUsdc.balanceOf(address(vaultUsdc)), 0);
        assertGt(vaultUsdc.accRewardPerlpToken(), 0);
        assertGt(vaultUsdc.lastATokenAmt(), 0);
        assertGt(vaultUsdc.accRewardTokenAmt(), 0);
        // console.log(vaultUsdc.getUserPendingReward(address(this)));
        assertGt(vaultUsdc.getUserPendingReward(address(this)), 0);
        // Assume aUsdc increase
        hoax(0x96d2452047fCf17A881DB3CE13c828891C55A1BD);
        aUsdc.transfer(address(vaultUsdc), 1e6);
        accRewardPerlpToken = vaultUsdc.accRewardPerlpToken();
        lastATokenAmt = vaultUsdc.lastATokenAmt();
        userPendingVault = vaultUsdc.getUserPendingReward(address(this));
        vaultUsdc.harvest();
        assertGt(vaultUsdc.accRewardPerlpToken(), accRewardPerlpToken);
        assertGt(vaultUsdc.lastATokenAmt(), lastATokenAmt);
        assertGt(vaultUsdc.getUserPendingReward(address(this)), userPendingVault);
    }

    function testClaim() public {
        testHarvest();

        // record variable before claim
        uint userPendingRewardWbtc = vaultWbtc.getUserPendingReward(address(this));
        uint userPendingRewardWeth = vaultWeth.getUserPendingReward(address(this));
        uint userPendingRewardUsdc = vaultUsdc.getUserPendingReward(address(this));

        // claim
        vaultWbtc.claim();
        vaultWeth.claim();
        vaultUsdc.claim();

        uint rewardStartAt;
        // assertion check
        // vaultWbtc
        assertEq(wbtc.balanceOf(address(this)), userPendingRewardWbtc);
        assertLe(vaultWbtc.lastATokenAmt(), 2);
        assertLe(aWbtc.balanceOf(address(vaultWbtc)), 2);
        (, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertGt(rewardStartAt, 0);

        // vaultWeth
        assertEq(weth.balanceOf(address(this)), userPendingRewardWeth);
        assertLe(vaultWeth.lastATokenAmt(), 2);
        assertLe(aWeth.balanceOf(address(vaultWeth)), 2);
        (, rewardStartAt) = vaultWeth.userInfo(address(this));
        assertGt(rewardStartAt, 0);

        // vaultUsdc
        assertEq(usdc.balanceOf(address(this)), userPendingRewardUsdc);
        assertLe(vaultUsdc.lastATokenAmt(), 2);
        assertLe(aUsdc.balanceOf(address(vaultUsdc)), 2);
        (, rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertGt(rewardStartAt, 0);
    }

    function testPauseContract() public {
        // Pause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vaultUsdc.pauseContract();
        vm.stopPrank();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWbtc.deposit(crv, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWeth.deposit(crv, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultUsdc.deposit(crv, 1 ether, 0);

        // Unpause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.unPauseContract();
        vaultWeth.unPauseContract();
        vaultUsdc.unPauseContract();
        vm.stopPrank();
        deal(address(crv), address(this), 3 ether);
        crv.approve(address(vaultWbtc), type(uint).max);
        crv.approve(address(vaultWeth), type(uint).max);
        crv.approve(address(vaultUsdc), type(uint).max);
        vaultWbtc.deposit(crv, 1 ether, 0);
        vaultWeth.deposit(crv, 1 ether, 0);
        vaultUsdc.deposit(crv, 1 ether, 0);

        // Pause contract and test withdraw
        vm.roll(block.number + 1);
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vaultUsdc.pauseContract();
        vm.stopPrank();
        vaultWbtc.withdraw(crv, vaultWbtc.getUserBalance(address(this)), 0);
        vaultWeth.withdraw(crv, vaultWeth.getUserBalance(address(this)), 0);
        vaultUsdc.withdraw(crv, vaultUsdc.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbCvxCrv vaultImpl = new PbCvxCrv();
        startHoax(owner);
        vaultWbtc.upgradeTo(address(vaultImpl));
        vaultWeth.upgradeTo(address(vaultImpl));
        vaultUsdc.upgradeTo(address(vaultImpl));
    }

    function testSetter() public {
        startHoax(owner);
        vaultWbtc.setYieldFeePerc(1000);
        assertEq(vaultWbtc.yieldFeePerc(), 1000);
        vaultWeth.setYieldFeePerc(1000);
        assertEq(vaultWeth.yieldFeePerc(), 1000);
        vaultUsdc.setYieldFeePerc(1000);
        assertEq(vaultUsdc.yieldFeePerc(), 1000);
        vaultWbtc.setTreasury(address(1));
        assertEq(vaultWbtc.treasury(), address(1));
        vaultWeth.setTreasury(address(1));
        assertEq(vaultWeth.treasury(), address(1));
        vaultUsdc.setTreasury(address(1));
        assertEq(vaultUsdc.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultWbtc.owner(), owner);
        assertEq(vaultWeth.owner(), owner);
        assertEq(vaultUsdc.owner(), owner);

        // TransferOwnership
        startHoax(owner);
        vaultWbtc.transferOwnership(address(1));
        vaultWeth.transferOwnership(address(1));
        vaultUsdc.transferOwnership(address(1));

        // vaultWbtc
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultWbtc.initialize(0, IPool(address(0)), IERC20Upgradeable(address(0)));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWbtc.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWbtc.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWbtc.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWbtc.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWbtc.setTreasury(address(0));

        // vaultWeth
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultWeth.initialize(0, IPool(address(0)), IERC20Upgradeable(address(0)));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWeth.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWeth.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWeth.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWeth.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultWeth.setTreasury(address(0));

        // vaultUsdc
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vaultUsdc.initialize(0, IPool(address(0)), IERC20Upgradeable(address(0)));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUsdc.pauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUsdc.unPauseContract();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUsdc.upgradeTo(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUsdc.setYieldFeePerc(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultUsdc.setTreasury(address(0));
    }

    receive() external payable {}
}
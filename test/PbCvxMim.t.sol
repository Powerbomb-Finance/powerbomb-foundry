// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbCvxMim.sol";
import "../interface/IPool.sol";
import "../interface/IZap.sol";

contract PbCvxMimTest is Test {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdt = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable dai = IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Upgradeable mim = IERC20Upgradeable(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IERC20Upgradeable spell = IERC20Upgradeable(0x090185f2135308BaD17527004364eBcC2D37e5F6);
    IERC20Upgradeable crv = IERC20Upgradeable(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Upgradeable cvx = IERC20Upgradeable(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    PbCvxMim vaultWbtc;
    PbCvxMim vaultWeth;
    PbCvxMim vaultUsdc;
    IPool pool = IPool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    IZap zap = IZap(0xA79828DF1850E8a3A3064576f380D90aECDD3359);
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWbtc = IERC20Upgradeable(0x13B2f6928D7204328b0E8E4BCd0379aA06EA21FA);
    IERC20Upgradeable aWeth = IERC20Upgradeable(0xf9Fb4AD91812b704Ba883B11d2B576E890a6730A);
    IERC20Upgradeable aUsdc = IERC20Upgradeable(0xd24946147829DEaA935bE2aD85A3291dbf109c80);
    address owner = address(this);

    function setUp() public {
        // Deploy implementation contract
        PbCvxMim vaultImpl = new PbCvxMim();
        PbProxy proxy;
        uint pid = 40;

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
        vaultWbtc = PbCvxMim(payable(address(proxy)));

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
        vaultWeth = PbCvxMim(payable(address(proxy)));

        lpToken = vaultWbtc.lpToken();
    }

    // function test() public {
    //     deal(address(mim), address(this), 10000 ether);
    //     mim.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(mim, 10000 ether, 0);
    //     deal(address(dai), address(this), 10000 ether);
    //     dai.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(dai, 10000 ether, 0);
    //     deal(address(usdc), address(this), 10000e6);
    //     usdc.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(usdc, 10000e6, 0);
    //     deal(address(usdt), address(this), 10000e6);
    //     usdt.safeApprove(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(usdt, 10000e6, 0);
    //     deal(address(lpToken), address(this), 10000 ether);
    //     lpToken.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(lpToken, 10000 ether, 0);
    //     // console.log(vaultWbtc.getAllPoolInUSD());

    //     skip(864000);
    //     // (uint pendingCrv, uint pendingCvx) = vaultWbtc.getPoolPendingReward();
    //     // console.log(pendingCrv);
    //     // console.log(pendingCvx);
    //     // uint pendingSpell = vaultWbtc.getPoolExtraPendingReward();
    //     // console.log(pendingSpell);
    //     deal(address(crv), address(vaultWbtc), 1.1 ether);
    //     deal(address(cvx), address(vaultWbtc), 1.1 ether);
    //     deal(address(spell), address(vaultWbtc), 1000.1 ether);
    //     vaultWbtc.harvest();
    //     // console.log(aWbtc.balanceOf(address(vaultWbtc)));
    //     vaultWbtc.claim();

    //     vm.roll(block.number + 1);
    //     uint lpTokenAmt = vaultWbtc.getUserBalance(address(this)) / 4;
    //     vaultWbtc.withdraw(mim, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(usdt, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(usdc, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(dai, lpTokenAmt, 0);
    // }

    function testDeposit() public {
        uint[4] memory amounts;
        uint amountOut;

        // deposit mim into vaultWbtc
        deal(address(mim), address(this), 10000 ether);
        mim.approve(address(vaultWbtc), type(uint).max);
        amounts = [10000 ether, uint(0), uint(0), uint(0)];
        amountOut = zap.calc_token_amount(address(pool), amounts, true);
        // console.log(amountOut);
        vaultWbtc.deposit(mim, 10000 ether, amountOut * 99 / 100);
        // console.log(vaultWbtc.getAllPool());

        // deposit usdt into vaultWeth
        deal(address(usdt), address(this), 10000e6);
        usdt.safeApprove(address(vaultWeth), type(uint).max);
        amounts = [uint(0), uint(0), uint(0), 10000e6];
        amountOut = zap.calc_token_amount(address(pool), amounts, true);
        // console.log(amountOut);
        vaultWeth.deposit(usdt, 10000e6, amountOut * 99 / 100);
        // console.log(vaultWeth.getAllPool());

        // deposit usdc into vaultWbtc
        deal(address(usdc), address(this), 10000e6);
        usdc.safeApprove(address(vaultWbtc), type(uint).max);
        amounts = [uint(0), uint(0), 10000e6, uint(0)];
        amountOut = zap.calc_token_amount(address(pool), amounts, true);
        // console.log(amountOut);
        vaultWbtc.deposit(usdc, 10000e6, amountOut * 99 / 100);
        // console.log(vaultWbtc.getAllPool());

        // deposit dai into vaultWeth
        deal(address(dai), address(this), 10000 ether);
        dai.safeApprove(address(vaultWeth), type(uint).max);
        amounts = [uint(0), 10000 ether, uint(0), uint(0)];
        amountOut = zap.calc_token_amount(address(pool), amounts, true);
        // console.log(amountOut);
        vaultWeth.deposit(dai, 10000 ether, amountOut * 99 / 100);
        // console.log(vaultWeth.getAllPool());

        // deposit lp token into vaultWbtc
        deal(address(lpToken), address(this), 10000 ether);
        lpToken.approve(address(vaultWbtc), type(uint).max);
        vaultWbtc.deposit(lpToken, 10000 ether, 0);

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
        assertEq(mim.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);

        // console.log(vaultWeth.getAllPool());
        assertGt(vaultWeth.getAllPool(), 0);
        // console.log(vaultWeth.getAllPoolInUSD());
        assertGt(vaultWeth.getAllPoolInUSD(), 0);
        // console.log(vaultWeth.getUserBalance(address(this)));
        assertGt(vaultWeth.getUserBalance(address(this)), 0);
        // console.log(vaultWeth.getUserBalanceInUSD(address(this)));
        assertGt(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        assertEq(mim.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint amountOut;

        // withdraw mim from vaultWbtc
        amountOut = zap.calc_withdraw_one_coin(address(pool), vaultWbtc.getUserBalance(address(this)) / 3, int128(0));
        // console.log(amountOut);
        vaultWbtc.withdraw(mim, vaultWbtc.getUserBalance(address(this)) / 3, amountOut * 99 / 100);

        // withdraw usdt from vaultWeth
        amountOut = zap.calc_withdraw_one_coin(address(pool), vaultWeth.getUserBalance(address(this)) / 2, int128(3));
        // console.log(amountOut);
        vaultWeth.withdraw(usdt, vaultWeth.getUserBalance(address(this)) / 2, amountOut * 99 / 100);

        // withdraw usdc from vaultWbtc
        amountOut = zap.calc_withdraw_one_coin(address(pool), vaultWbtc.getUserBalance(address(this)) / 2, int128(2));
        // console.log(amountOut);
        vaultWbtc.withdraw(usdc, vaultWbtc.getUserBalance(address(this)) / 2, amountOut * 99 / 100);

        // withdraw dai from vaultWeth
        amountOut = zap.calc_withdraw_one_coin(address(pool), vaultWeth.getUserBalance(address(this)), int128(1));
        // console.log(amountOut);
        vaultWeth.withdraw(dai, vaultWeth.getUserBalance(address(this)), amountOut * 99 / 100);

        // withdraw lp token
        vaultWbtc.withdraw(lpToken, vaultWbtc.getUserBalance(address(this)), 0);

        uint lpTokenAmt;
        uint rewardStartAt;
        // assertion check
        // vaultWbtc
        assertEq(vaultWbtc.getAllPool(), 0);
        assertEq(vaultWbtc.getAllPoolInUSD(), 0);
        assertEq(vaultWbtc.getUserBalance(address(this)), 0);
        assertEq(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        // console.log(mim.balanceOf(address(this)));
        assertGt(mim.balanceOf(address(this)), 0);
        // console.log(usdc.balanceOf(address(this)));
        assertGt(usdc.balanceOf(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(mim.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);
        (lpTokenAmt, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultWeth
        assertEq(vaultWeth.getAllPool(), 0);
        assertEq(vaultWeth.getAllPoolInUSD(), 0);
        assertEq(vaultWeth.getUserBalance(address(this)), 0);
        assertEq(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        // console.log(usdt.balanceOf(address(this)));
        assertGt(usdt.balanceOf(address(this)), 0);
        // console.log(dai.balanceOf(address(this)));
        assertGt(dai.balanceOf(address(this)), 0);
        assertEq(mim.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);
        (lpTokenAmt, rewardStartAt) = vaultWeth.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);

        uint crvReward;
        uint cvxReward;
        uint spellReward;
        // check pending reward
        (crvReward, cvxReward) = vaultWbtc.getPoolPendingReward();
        (spellReward) = vaultWbtc.getPoolExtraPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        // console.log(spellReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0);
        assertEq(spellReward, 0); // no spell reward currently
        (crvReward, cvxReward) = vaultWeth.getPoolPendingReward();
        (spellReward) = vaultWeth.getPoolExtraPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        // console.log(spellReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0); 
        assertEq(spellReward, 0);

        // assume crv & cvx > 1 ether, spell > 1000 ether
        deal(address(crv), address(vaultWbtc), 1.1 ether);
        deal(address(cvx), address(vaultWbtc), 1.1 ether);
        deal(address(spell), address(vaultWbtc), 1000.1 ether);
        deal(address(crv), address(vaultWeth), 1.1 ether);
        deal(address(cvx), address(vaultWeth), 1.1 ether);
        deal(address(spell), address(vaultWeth), 1000.1 ether);

        // harvest
        vaultWbtc.harvest();
        vaultWeth.harvest();

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
    }

    function testClaim() public {
        testHarvest();

        // record variable before claim
        uint userPendingRewardWbtc = vaultWbtc.getUserPendingReward(address(this));
        uint userPendingRewardWeth = vaultWeth.getUserPendingReward(address(this));

        // claim
        vaultWbtc.claim();
        vaultWeth.claim();

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
    }

    function testPauseContract() public {
        // Pause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vm.stopPrank();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWbtc.deposit(usdc, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWeth.deposit(usdc, 1 ether, 0);

        // Unpause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.unPauseContract();
        vaultWeth.unPauseContract();
        vm.stopPrank();
        deal(address(usdc), address(this), 2 ether);
        usdc.approve(address(vaultWbtc), type(uint).max);
        usdc.approve(address(vaultWeth), type(uint).max);
        vaultWbtc.deposit(usdc, 1 ether, 0);
        vaultWeth.deposit(usdc, 1 ether, 0);

        // Pause contract and test withdraw
        vm.roll(block.number + 1);
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vm.stopPrank();
        vaultWbtc.withdraw(usdc, vaultWbtc.getUserBalance(address(this)), 0);
        vaultWeth.withdraw(usdc, vaultWeth.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbCvxMim vaultImpl = new PbCvxMim();
        startHoax(owner);
        vaultWbtc.upgradeTo(address(vaultImpl));
        vaultWeth.upgradeTo(address(vaultImpl));
    }

    function testSetter() public {
        startHoax(owner);
        vaultWbtc.setYieldFeePerc(1000);
        assertEq(vaultWbtc.yieldFeePerc(), 1000);
        vaultWeth.setYieldFeePerc(1000);
        assertEq(vaultWeth.yieldFeePerc(), 1000);
        vaultWbtc.setTreasury(address(1));
        assertEq(vaultWbtc.treasury(), address(1));
        vaultWeth.setTreasury(address(1));
        assertEq(vaultWeth.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultWbtc.owner(), owner);
        assertEq(vaultWeth.owner(), owner);

        // TransferOwnership
        startHoax(owner);
        vaultWbtc.transferOwnership(address(1));
        vaultWeth.transferOwnership(address(1));

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
    }
    
    receive() external payable {}
}
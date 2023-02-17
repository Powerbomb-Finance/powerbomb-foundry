// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbAuraUsdc.sol";
import "../interface/IBalancerHelper.sol";

contract PbAuraUsdcTest is Test {

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable aura = IERC20Upgradeable(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20Upgradeable bal = IERC20Upgradeable(0xba100000625a3754423978a60c9317c58a424e3D);
    IBalancerHelper balancerHelper = IBalancerHelper(0x5aDDCCa35b7A0D07C74063c48700C8590E87864E);
    PbAuraUsdc vaultWbtc;
    PbAuraUsdc vaultWeth;
    PbAuraUsdc vaultUsdc;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWbtc = IERC20Upgradeable(0x13B2f6928D7204328b0E8E4BCd0379aA06EA21FA);
    IERC20Upgradeable aWeth = IERC20Upgradeable(0xf9Fb4AD91812b704Ba883B11d2B576E890a6730A);
    IERC20Upgradeable aUsdc = IERC20Upgradeable(0xd24946147829DEaA935bE2aD85A3291dbf109c80);
    bytes32 poolId = 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019;
    address owner = address(this);

    function setUp() public {
        // Deploy implementation contract
        PbAuraUsdc vaultImpl = new PbAuraUsdc();
        PbProxy proxy;

        // Deploy wbtc reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                6,
                address(wbtc)
            )
        );
        vaultWbtc = PbAuraUsdc(payable(address(proxy)));

        // Deploy weth reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                6,
                address(weth)
            )
        );
        vaultWeth = PbAuraUsdc(payable(address(proxy)));

        // Deploy usdc reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                6,
                address(usdc)
            )
        );
        vaultUsdc = PbAuraUsdc(payable(address(proxy)));

        lpToken = vaultUsdc.lpToken();
    }

    // function test() public {
    //     deal(address(usdc), address(this), 10000e6);
    //     usdc.approve(address(vaultUsdc), type(uint).max);
    //     vaultUsdc.deposit(usdc, 10000e6, 0);
    //     vaultUsdc.deposit{value: 10 ether}(weth, 10 ether, 0);
    //     console.log(vaultUsdc.getAllPoolInUSD());
    //     skip(864000);
    //     (uint pendingBal, uint pendingAura) = vaultUsdc.getPoolPendingReward();
    //     console.log(pendingBal);
    //     console.log(pendingAura);
    //     deal(address(aura), address(vaultUsdc), 1.1 ether);
    //     deal(address(bal), address(vaultUsdc), 1.1 ether);
    //     vaultUsdc.harvest();
    //     console.log(aUsdc.balanceOf(address(vaultUsdc)));
    //     vaultUsdc.claim();
    //     vm.roll(block.number + 1);
    //     vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)) / 2, 0);
    //     vaultUsdc.withdraw(usdc, vaultUsdc.getUserBalance(address(this)), 0);
    // }

    function testDeposit() public {
        // Deposit native eth into vaultWbtc
        uint[] memory maxAmountsIn = new uint[](2);
        maxAmountsIn[1] = 10 ether;
        IBalancer.JoinPoolRequest memory request = IBalancer.JoinPoolRequest({
            assets: _getAssets(),
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
            fromInternalBalance: false
        });
        (uint amountOut,) = balancerHelper.queryJoin(poolId, address(this), address(this), request);
        vaultWbtc.deposit{value: 10 ether}(weth, 10 ether, amountOut * 99 / 100);

        // Deposit usdc into vaultWeth
        deal(address(usdc), address(this), 10000e6);
        maxAmountsIn[0] = 10000e6;
        maxAmountsIn[1] = 0;
        request = IBalancer.JoinPoolRequest({
            assets: _getAssets(),
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
            fromInternalBalance: false
        });
        (amountOut,) = balancerHelper.queryJoin(poolId, address(this), address(this), request);
        usdc.approve(address(vaultWeth), type(uint).max);
        vaultWeth.deposit(usdc, 10000e6, amountOut * 99 / 100);

        // Deposit lp token into vaultUsdc
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
        assertEq(weth.balanceOf(address(vaultWbtc)), 0);

        //vaultWeth
        // console.log(vaultWeth.getAllPool());
        assertGt(vaultWeth.getAllPool(), 0);
        // console.log(vaultWeth.getAllPoolInUSD());
        assertGt(vaultWeth.getAllPoolInUSD(), 0);
        // console.log(vaultWeth.getUserBalance(address(this)));
        assertGt(vaultWeth.getUserBalance(address(this)), 0);
        // console.log(vaultWeth.getUserBalanceInUSD(address(this)));
        assertGt(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), 0);

        // vaultUsdc
        // console.log(vaultUsdc.getAllPool());
        assertGt(vaultUsdc.getAllPool(), 0);
        // console.log(vaultUsdc.getAllPoolInUSD());
        assertGt(vaultUsdc.getAllPoolInUSD(), 0);
        // console.log(vaultUsdc.getUserBalance(address(this)));
        assertGt(vaultUsdc.getUserBalance(address(this)), 0);
        // console.log(vaultUsdc.getUserBalanceInUSD(address(this)));
        assertGt(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint lpTokenAmt;
        IBalancer.ExitPoolRequest memory request;
        uint[] memory amountsOut;

        // withdraw native eth from vaultWbtc
        uint balBef = address(this).balance;
        uint[] memory minAmountsOut = new uint[](2);
        lpTokenAmt = vaultWbtc.getUserBalance(address(this));
        request = IBalancer.ExitPoolRequest({
            assets: _getAssets(),
            minAmountsOut: minAmountsOut,
            userData: abi.encode(
                IBalancer.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                lpTokenAmt,
                1
            ),
            toInternalBalance: false
        });
        (, amountsOut) = balancerHelper.queryExit(poolId, address(this), address(this), request);
        vaultWbtc.withdraw(weth, lpTokenAmt, amountsOut[1] * 99 / 100);

        // withdraw usdc from vaultWeth
        lpTokenAmt = vaultWeth.getUserBalance(address(this));
        request = IBalancer.ExitPoolRequest({
            assets: _getAssets(),
            minAmountsOut: minAmountsOut,
            userData: abi.encode(
                IBalancer.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                lpTokenAmt,
                0
            ),
            toInternalBalance: false
        });
        (, amountsOut) = balancerHelper.queryExit(poolId, address(this), address(this), request);
        vaultWeth.withdraw(usdc, lpTokenAmt, amountsOut[0] * 99 / 100);

        // withdraw lp token from vaultUsdc
        vaultUsdc.withdraw(lpToken, vaultUsdc.getUserBalance(address(this)), 0);

        // assertion check
        uint _lpTokenAmt;
        uint rewardStartAt;
        // vaultWbtc
        assertEq(vaultWbtc.getAllPool(), 0);
        assertEq(vaultWbtc.getAllPoolInUSD(), 0);
        assertEq(vaultWbtc.getUserBalance(address(this)), 0);
        assertEq(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - balBef);
        assertGt(address(this).balance, balBef);
        assertEq(address(vaultWbtc).balance, 0);
        assertEq(weth.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        assertEq(lpToken.balanceOf(address(vaultWbtc)), 0);
        (_lpTokenAmt, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultWeth
        assertEq(vaultWeth.getAllPool(), 0);
        assertEq(vaultWeth.getAllPoolInUSD(), 0);
        assertEq(vaultWeth.getUserBalance(address(this)), 0);
        assertEq(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        // console.log(usdc.balanceOf(address(this)));
        assertGt(usdc.balanceOf(address(this)), 0);
        assertEq(address(vaultWeth).balance, 0);
        assertEq(weth.balanceOf(address(vaultWeth)), 0);
        assertEq(usdc.balanceOf(address(vaultWeth)), 0);
        assertEq(lpToken.balanceOf(address(vaultWeth)), 0);
        (_lpTokenAmt, rewardStartAt) = vaultWeth.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultUsdc
        assertEq(vaultUsdc.getAllPool(), 0);
        assertEq(vaultUsdc.getAllPoolInUSD(), 0);
        assertEq(vaultUsdc.getUserBalance(address(this)), 0);
        assertEq(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(weth.balanceOf(address(vaultUsdc)), 0);
        assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
        assertEq(lpToken.balanceOf(address(vaultUsdc)), 0);
        (_lpTokenAmt, rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);

        // check pending reward
        uint balReward;
        uint auraReward;
        (balReward, auraReward) = vaultWbtc.getPoolPendingReward();
        // console.log(balReward);
        // console.log(auraReward);
        assertGt(balReward, 0);
        assertGt(auraReward, 0);
        (balReward, auraReward) = vaultWeth.getPoolPendingReward();
        // console.log(balReward);
        // console.log(auraReward);
        assertGt(balReward, 0);
        assertGt(auraReward, 0);
        (balReward, auraReward) = vaultUsdc.getPoolPendingReward();
        // console.log(balReward);
        // console.log(auraReward);
        assertGt(balReward, 0);
        assertGt(auraReward, 0);

        // assume bal & aura > 1 ether
        deal(address(bal), address(vaultWbtc), 1.1 ether);
        deal(address(aura), address(vaultWbtc), 1.1 ether);
        deal(address(bal), address(vaultWeth), 1.1 ether);
        deal(address(aura), address(vaultWeth), 1.1 ether);
        deal(address(bal), address(vaultUsdc), 1.1 ether);
        deal(address(aura), address(vaultUsdc), 1.1 ether);

        // harvest
        vaultWbtc.harvest();
        vaultWeth.harvest();
        vaultUsdc.harvest();

        // assertion check
        uint accRewardPerlpToken;
        uint lastATokenAmt;
        uint userPendingVault;
        // vaultWbtc
        assertEq(bal.balanceOf(address(vaultWbtc)), 0);
        assertEq(aura.balanceOf(address(vaultWbtc)), 0);
        assertEq(usdc.balanceOf(address(vaultWbtc)), 0);
        // console.log(aWbtc.balanceOf(address(vaultWbtc)));
        assertGt(aWbtc.balanceOf(address(vaultWbtc)), 0);
        assertGt(vaultWbtc.accRewardPerlpToken(), 0);
        assertGt(vaultWbtc.lastATokenAmt(), 0);
        assertGt(vaultWbtc.accRewardTokenAmt(), 0);
        // console.log(vaultWbtc.getUserPendingReward(address(this)));
        assertGt(vaultWbtc.getUserPendingReward(address(this)), 0);
        // Assume aWbtc increase
        hoax(0xB58163D9148EfFEdF4eF8517Ad1D3251b1ddD837);
        aWbtc.transfer(address(vaultWbtc), 1e6);
        accRewardPerlpToken = vaultWbtc.accRewardPerlpToken();
        lastATokenAmt = vaultWbtc.lastATokenAmt();
        userPendingVault = vaultWbtc.getUserPendingReward(address(this));
        vaultWbtc.harvest();
        assertGt(vaultWbtc.accRewardPerlpToken(), accRewardPerlpToken);
        assertGt(vaultWbtc.lastATokenAmt(), lastATokenAmt);
        assertGt(vaultWbtc.getUserPendingReward(address(this)), userPendingVault);

        // vaultWeth
        assertEq(bal.balanceOf(address(vaultWeth)), 0);
        assertEq(aura.balanceOf(address(vaultWeth)), 0);
        assertEq(usdc.balanceOf(address(vaultWeth)), 0);
        // console.log(aWeth.balanceOf(address(vaultWeth)));
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
        assertEq(bal.balanceOf(address(vaultUsdc)), 0);
        assertEq(aura.balanceOf(address(vaultUsdc)), 0);
        assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
        // console.log(aUsdc.balanceOf(address(vaultUsdc)));
        assertGt(aUsdc.balanceOf(address(vaultUsdc)), 0);
        assertGt(vaultUsdc.accRewardPerlpToken(), 0);
        assertGt(vaultUsdc.lastATokenAmt(), 0);
        assertGt(vaultUsdc.accRewardTokenAmt(), 0);
        // console.log(vaultUsdc.getUserPendingReward(address(this)));
        assertGt(vaultUsdc.getUserPendingReward(address(this)), 0);
        // Assume aUsdc increase
        hoax(0x68B1B65F3792ed4179b68A657f3dec71A69ead79);
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

        // assertion check
        uint rewardStartAt;
        // vaultWbtc
        assertEq(wbtc.balanceOf(address(this)), userPendingRewardWbtc);
        assertLe(vaultWbtc.lastATokenAmt(), 1);
        assertLe(aWbtc.balanceOf(address(vaultWbtc)), 1);
        (, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertGt(rewardStartAt, 0);

        // vaultWeth
        assertEq(weth.balanceOf(address(this)), userPendingRewardWeth);
        assertLe(vaultUsdc.lastATokenAmt(), 1);
        assertLe(aWeth.balanceOf(address(vaultUsdc)), 1);
        (, rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertGt(rewardStartAt, 0);

        // vaultUsdc
        assertEq(usdc.balanceOf(address(this)), userPendingRewardUsdc);
        assertLe(vaultUsdc.lastATokenAmt(), 1);
        assertLe(aUsdc.balanceOf(address(vaultUsdc)), 1);
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
        vaultWbtc.deposit{value: 1 ether}(weth, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWeth.deposit{value: 1 ether}(weth, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
        // Unpause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.unPauseContract();
        vaultWeth.unPauseContract();
        vaultUsdc.unPauseContract();
        vm.stopPrank();
        vaultWbtc.deposit{value: 1 ether}(weth, 1 ether, 0);
        vaultWeth.deposit{value: 1 ether}(weth, 1 ether, 0);
        vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vaultUsdc.pauseContract();
        vm.stopPrank();
        vaultWbtc.withdraw(weth, vaultWbtc.getUserBalance(address(this)), 0);
        vaultWeth.withdraw(weth, vaultWeth.getUserBalance(address(this)), 0);
        vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbAuraUsdc vaultImpl = new PbAuraUsdc();
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
        vaultWbtc.initialize(0, IERC20Upgradeable(address(0)));
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
        vaultWeth.initialize(0, IERC20Upgradeable(address(0)));
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
        vaultUsdc.initialize(0, IERC20Upgradeable(address(0)));
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

    function _getAssets() private view returns (address[] memory assets) {
        assets = new address[](2);
        assets[0] = address(usdc);
        assets[1] = address(weth);
    }
    
    receive() external payable {}
}
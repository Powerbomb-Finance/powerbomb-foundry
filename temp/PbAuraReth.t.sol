// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbAuraReth.sol";
import "../interface/IBalancerHelper.sol";

contract PbAuraRethTest is Test {

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable reth = IERC20Upgradeable(0xae78736Cd615f374D3085123A210448E74Fc6393);
    IERC20Upgradeable aura = IERC20Upgradeable(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20Upgradeable bal = IERC20Upgradeable(0xba100000625a3754423978a60c9317c58a424e3D);
    IBalancerHelper balancerHelper = IBalancerHelper(0x5aDDCCa35b7A0D07C74063c48700C8590E87864E);
    PbAuraReth vaultUsdc;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aToken;
    bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
    address owner = address(this);

    function setUp() public {
        // Deploy implementation contract
        PbAuraReth vaultImpl = new PbAuraReth();

        // Deploy usdc reward proxy contract
        PbProxy proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                21,
                address(usdc)
            )
        );
        vaultUsdc = PbAuraReth(payable(address(proxy)));

        lpToken = vaultUsdc.lpToken();
        aToken = vaultUsdc.aToken();
    }

    // function test() public {
    //     vaultUsdc.deposit{value: 100 ether}(weth, 100 ether, 0);
    //     console.log(vaultUsdc.getAllPoolInUSD());
    //     skip(864000);
    //     deal(address(aura), address(vaultUsdc), 1.1 ether);
    //     deal(address(bal), address(vaultUsdc), 1.1 ether);
    //     vaultUsdc.harvest();
    //     vaultUsdc.claim();
    //     vm.roll(block.number + 1);
    //     vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)) / 2, 0);
    //     vaultUsdc.withdraw(reth, vaultUsdc.getUserBalance(address(this)), 0);
    // }

    function testDeposit() public {
        // Deposit native eth
        uint[] memory maxAmountsIn = new uint[](2);
        maxAmountsIn[1] = 10 ether;
        IBalancer.JoinPoolRequest memory request = IBalancer.JoinPoolRequest({
            assets: _getAssets(),
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
            fromInternalBalance: false
        });
        (uint amountOut,) = balancerHelper.queryJoin(poolId, address(this), address(this), request);
        vaultUsdc.deposit{value: 10 ether}(weth, 10 ether, amountOut * 99 / 100);
        // Deposit reth
        deal(address(reth), address(this), 10 ether);
        reth.transfer(address(this), 10 ether);
        maxAmountsIn[0] = 10 ether;
        maxAmountsIn[1] = 0;
        request = IBalancer.JoinPoolRequest({
            assets: _getAssets(),
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
            fromInternalBalance: false
        });
        (amountOut,) = balancerHelper.queryJoin(poolId, address(this), address(this), request);
        reth.approve(address(vaultUsdc), type(uint).max);
        vaultUsdc.deposit(reth, 10 ether, amountOut * 99 / 100);
        // Deposit lp token
        deal(address(lpToken), address(this), 10 ether);
        lpToken.approve(address(vaultUsdc), type(uint).max);
        vaultUsdc.deposit(lpToken, 10 ether, 0);
        // assertion check
        // console.log(vaultUsdc.getAllPool());
        assertGt(vaultUsdc.getAllPool(), 0);
        // console.log(vaultUsdc.getAllPoolInUSD());
        assertGt(vaultUsdc.getAllPoolInUSD(), 0);
        // console.log(vaultUsdc.getUserBalance(address(this)));
        assertGt(vaultUsdc.getUserBalance(address(this)), 0);
        // console.log(vaultUsdc.getUserBalanceInUSD(address(this)));
        assertGt(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(weth.balanceOf(address(vaultUsdc)), 0);
        assertEq(reth.balanceOf(address(this)), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint balBef = address(this).balance;
        // withdraw native eth
        uint[] memory minAmountsOut = new uint[](2);
        uint lpTokenAmt = vaultUsdc.getUserBalance(address(this)) / 3;
        IBalancer.ExitPoolRequest memory request = IBalancer.ExitPoolRequest({
            assets: _getAssets(),
            minAmountsOut: minAmountsOut,
            userData: abi.encode(
                IBalancer.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                lpTokenAmt,
                1
            ),
            toInternalBalance: false
        });
        (, uint[] memory amountsOut) = balancerHelper.queryExit(poolId, address(this), address(this), request);
        vaultUsdc.withdraw(weth, lpTokenAmt, amountsOut[1] * 99 / 100);
        // withdraw reth
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
        vaultUsdc.withdraw(reth, lpTokenAmt, amountsOut[0] * 99 / 100);
        // withdraw lp token
        vaultUsdc.withdraw(lpToken, vaultUsdc.getUserBalance(address(this)), 0);
        // assertion check
        assertEq(vaultUsdc.getAllPool(), 0);
        assertEq(vaultUsdc.getAllPoolInUSD(), 0);
        assertEq(vaultUsdc.getUserBalance(address(this)), 0);
        assertEq(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - balBef);
        assertGt(address(this).balance, balBef);
        // console.log(reth.balanceOf(address(this)));
        assertGt(reth.balanceOf(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(weth.balanceOf(address(vaultUsdc)), 0);
        assertEq(reth.balanceOf(address(vaultUsdc)), 0);
        assertEq(lpToken.balanceOf(address(vaultUsdc)), 0);
        (uint _lpTokenAmt, uint rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);
        // check pending reward
        (uint balReward, uint auraReward) = vaultUsdc.getPoolPendingReward();
        // console.log(balReward);
        // console.log(auraReward);
        assertGt(balReward, 0);
        assertGt(auraReward, 0);
        // assume bal & aura > 1 ether
        deal(address(bal), address(vaultUsdc), 1.1 ether);
        deal(address(aura), address(vaultUsdc), 1.1 ether);
        // harvest
        vaultUsdc.harvest();
        // assertion check
        assertEq(bal.balanceOf(address(vaultUsdc)), 0);
        assertEq(aura.balanceOf(address(vaultUsdc)), 0);
        assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
        // console.log(aToken.balanceOf(address(vaultUsdc)));
        assertGt(aToken.balanceOf(address(vaultUsdc)), 0);
        assertGt(vaultUsdc.accRewardPerlpToken(), 0);
        assertGt(vaultUsdc.lastATokenAmt(), 0);
        assertGt(vaultUsdc.accRewardTokenAmt(), 0);
        // console.log(vaultUsdc.getUserPendingReward(address(this)));
        assertGt(vaultUsdc.getUserPendingReward(address(this)), 0);
        // Assume aToken increase
        hoax(0x68B1B65F3792ed4179b68A657f3dec71A69ead79);
        aToken.transfer(address(vaultUsdc), 1e6);
        uint accRewardPerlpToken = vaultUsdc.accRewardPerlpToken();
        uint lastATokenAmt = vaultUsdc.lastATokenAmt();
        uint userPendingVault = vaultUsdc.getUserPendingReward(address(this));
        vaultUsdc.harvest();
        assertGt(vaultUsdc.accRewardPerlpToken(), accRewardPerlpToken);
        assertGt(vaultUsdc.lastATokenAmt(), lastATokenAmt);
        assertGt(vaultUsdc.getUserPendingReward(address(this)), userPendingVault);
    }

    function testClaim() public {
        testHarvest();
        // record variable before claim
        uint userPendingReward = vaultUsdc.getUserPendingReward(address(this));
        // claim
        vaultUsdc.claim();
        // assertion check
        assertEq(usdc.balanceOf(address(this)), userPendingReward);
        assertLe(vaultUsdc.lastATokenAmt(), 1);
        assertLe(aToken.balanceOf(address(vaultUsdc)), 1);
        (, uint rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertGt(rewardStartAt, 0);
    }

    function testPauseContract() public {
        // Pause contract and test deposit
        hoax(owner);
        vaultUsdc.pauseContract();
        vm.expectRevert(bytes("Pausable: paused"));
        vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
        // Unpause contract and test deposit
        hoax(owner);
        vaultUsdc.unPauseContract();
        vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        hoax(owner);
        vaultUsdc.pauseContract();
        vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbAuraReth vaultImpl = new PbAuraReth();
        hoax(owner);
        vaultUsdc.upgradeTo(address(vaultImpl));
    }

    function testSetter() public {
        startHoax(owner);
        vaultUsdc.setYieldFeePerc(1000);
        assertEq(vaultUsdc.yieldFeePerc(), 1000);
        vaultUsdc.setTreasury(address(1));
        assertEq(vaultUsdc.treasury(), address(1));
    }

    function testAuthorization() public {
        assertEq(vaultUsdc.owner(), owner);
        // TransferOwnership
        startHoax(owner);
        vaultUsdc.transferOwnership(address(1));
        // Vault
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
        assets[0] = address(reth);
        assets[1] = address(weth);
    }
    
    receive() external payable {}
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbAuraStable.sol";
import "../interface/IBalancerHelper.sol";

contract PbAuraStableTest is Test {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdt = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable dai = IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Upgradeable aura = IERC20Upgradeable(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20Upgradeable bal = IERC20Upgradeable(0xba100000625a3754423978a60c9317c58a424e3D);
    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IBalancerHelper balancerHelper = IBalancerHelper(0x5aDDCCa35b7A0D07C74063c48700C8590E87864E);
    IERC20Upgradeable bbaUsdt = IERC20Upgradeable(0x2F4eb100552ef93840d5aDC30560E5513DFfFACb); // bb-a-usdt balancer
    bytes32 bbaUsdtPoolId = 0x2f4eb100552ef93840d5adc30560e5513dfffacb000000000000000000000334;
    IERC20Upgradeable bbaUsdc = IERC20Upgradeable(0x82698aeCc9E28e9Bb27608Bd52cF57f704BD1B83); // bb-a-usdc balancer
    bytes32 bbaUsdcPoolId = 0x82698aecc9e28e9bb27608bd52cf57f704bd1b83000000000000000000000336;
    IERC20Upgradeable bbaDai = IERC20Upgradeable(0xae37D54Ae477268B9997d4161B96b8200755935c); // bb-a-dai balancer
    bytes32 bbaDaiPoolId = 0xae37d54ae477268b9997d4161b96b8200755935c000000000000000000000337;
    IERC20Upgradeable bbaUsd = IERC20Upgradeable(0xA13a9247ea42D743238089903570127DdA72fE44); // bb-a-usd balancer, same as lpToken
    bytes32 bbaUsdPoolId = 0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d;
    PbAuraStable vaultWbtc;
    PbAuraStable vaultWeth;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aWbtc;
    IERC20Upgradeable aWeth;
    bytes32 poolId = 0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d;
    address owner = address(this);

    function setUp() public {
        // Deploy implementation contract
        PbAuraStable vaultImpl = new PbAuraStable();
        PbProxy proxy;
        uint pid = 41;

        // Deploy wbtc reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                pid,
                address(wbtc)
            )
        );
        vaultWbtc = PbAuraStable(payable(address(proxy)));

        // Deploy weth reward proxy contract
        proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                pid,
                address(weth)
            )
        );
        vaultWeth = PbAuraStable(payable(address(proxy)));

        lpToken = vaultWbtc.lpToken();
        aWbtc = vaultWbtc.aToken();
        aWeth = vaultWeth.aToken();
    }

    // function test() public {
    //     deal(address(usdt), address(this), 10000e6);
    //     usdt.safeApprove(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(usdt, 10000e6, 9990 ether);

    //     deal(address(usdc), address(this), 10000e6);
    //     usdc.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(usdc, 10000e6, 9990 ether);

    //     deal(address(dai), address(this), 10000 ether);
    //     dai.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(dai, 10000 ether, 9990 ether);

    //     deal(address(lpToken), address(this), 10000 ether);
    //     lpToken.approve(address(vaultWbtc), type(uint).max);
    //     vaultWbtc.deposit(lpToken, 10000 ether, 0);

    //     skip(864000);
    //     deal(address(aura), address(vaultWbtc), 1.1 ether);
    //     deal(address(bal), address(vaultWbtc), 1.1 ether);
    //     vaultWbtc.harvest();
    //     vaultWbtc.claim();

    //     vm.roll(block.number + 1);

    //     uint lpTokenAmt = vaultWbtc.getUserBalance(address(this)) / 4;
    //     vaultWbtc.withdraw(usdt, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(usdc, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(dai, lpTokenAmt, 0);
    //     vaultWbtc.withdraw(lpToken, lpTokenAmt, 0);
    // }

    function testDeposit() public {
        int[] memory assetDeltas;
        uint amountOut;
        address[] memory assets = new address[](3);
        assets[2] = address(bbaUsd);

        IBalancer.FundManagement memory funds = _getFunds();

        // deposit usdt into vaultWbtc
        assets[0] = address(usdt);
        assets[1] = address(bbaUsdt);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                10000e6,
                bbaUsdtPoolId,
                bbaUsdPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        deal(address(usdt), address(this), 10000e6);
        usdt.safeApprove(address(vaultWbtc), type(uint).max);
        vaultWbtc.deposit(usdt, 10000e6, amountOut * 99 / 100);

        // deposit usdc into vaultWeth
        assets[0] = address(usdc);
        assets[1] = address(bbaUsdc);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                10000e6,
                bbaUsdcPoolId,
                bbaUsdPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        deal(address(usdc), address(this), 10000e6);
        usdc.approve(address(vaultWeth), type(uint).max);
        vaultWeth.deposit(usdc, 10000e6, amountOut * 99 / 100);

        // deposit dai into vaultWbtc
        assets[0] = address(dai);
        assets[1] = address(bbaDai);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                10000 ether,
                bbaDaiPoolId,
                bbaUsdPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        deal(address(dai), address(this), 10000 ether);
        dai.approve(address(vaultWbtc), type(uint).max);
        vaultWbtc.deposit(dai, 10000 ether, amountOut * 99 / 100);

        // deposit lp token into vaultWeth
        deal(address(lpToken), address(this), 10000 ether);
        lpToken.approve(address(vaultWeth), type(uint).max);
        vaultWeth.deposit(lpToken, 10000 ether, 0);

        // assertion check
        // console.log(vaultWbtc.getAllPool());
        assertGt(vaultWbtc.getAllPool(), 0);
        // console.log(vaultWbtc.getAllPoolInUSD());
        assertGt(vaultWbtc.getAllPoolInUSD(), 0);
        // console.log(vaultWbtc.getUserBalance(address(this)));
        assertGt(vaultWbtc.getUserBalance(address(this)), 0);
        // console.log(vaultWbtc.getUserBalanceInUSD(address(this)));
        assertGt(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);

        // console.log(vaultWeth.getAllPool());
        assertGt(vaultWeth.getAllPool(), 0);
        // console.log(vaultWeth.getAllPoolInUSD());
        assertGt(vaultWeth.getAllPoolInUSD(), 0);
        // console.log(vaultWeth.getUserBalance(address(this)));
        assertGt(vaultWeth.getUserBalance(address(this)), 0);
        // console.log(vaultWeth.getUserBalanceInUSD(address(this)));
        assertGt(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        assertEq(usdc.balanceOf(address(vaultWeth)), 0);
        assertEq(lpToken.balanceOf(address(vaultWeth)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);

        int[] memory assetDeltas;
        uint amountOut;
        IBalancer.FundManagement memory funds = _getFunds();
        address[] memory assets = new address[](3);
        assets[0] = address(bbaUsd);

        uint vaultWbtcLpTokenAmt = vaultWbtc.getUserBalance(address(this)) / 2;
        uint vaultWethLpTokenAmt = vaultWeth.getUserBalance(address(this)) / 2;

        // withdraw usdt
        assets[1] = address(bbaUsdt);
        assets[2] = address(usdt);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWbtcLpTokenAmt,
                bbaUsdPoolId,
                bbaUsdtPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWbtc.withdraw(usdt, vaultWbtcLpTokenAmt, amountOut * 99 / 100);

        // withdraw usdc
        assets[1] = address(bbaUsdc);
        assets[2] = address(usdc);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWethLpTokenAmt,
                bbaUsdPoolId,
                bbaUsdcPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWeth.withdraw(usdc, vaultWethLpTokenAmt, amountOut * 99 / 100);

        // withdraw dai
        assets[1] = address(bbaDai);
        assets[2] = address(dai);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWbtcLpTokenAmt,
                bbaUsdPoolId,
                bbaDaiPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWbtc.withdraw(dai, vaultWbtcLpTokenAmt, amountOut * 99 / 100);

        // withdraw lp token
        vaultWeth.withdraw(lpToken, vaultWeth.getUserBalance(address(this)), 0);

        uint _lpTokenAmt;
        uint rewardStartAt;
        // assertion check
        // vaultWbtc
        assertEq(vaultWbtc.getAllPool(), 0);
        assertEq(vaultWbtc.getAllPoolInUSD(), 0);
        assertEq(vaultWbtc.getUserBalance(address(this)), 0);
        assertEq(vaultWbtc.getUserBalanceInUSD(address(this)), 0);
        // console.log(usdt.balanceOf(address(this)));
        assertGt(usdt.balanceOf(address(this)), 0);
        // console.log(dai.balanceOf(address(this)));
        assertGt(dai.balanceOf(address(this)), 0);
        assertEq(usdt.balanceOf(address(vaultWbtc)), 0);
        assertEq(dai.balanceOf(address(vaultWbtc)), 0);
        (_lpTokenAmt, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);

        // vaultWeth
        
    }

    // function testHarvest() public {
    //     testDeposit();
    //     skip(864000);
    //     // check pending reward
    //     (uint balReward, uint auraReward) = vaultUsdc.getPoolPendingReward();
    //     // console.log(balReward);
    //     // console.log(auraReward);
    //     assertGt(balReward, 0);
    //     assertGt(auraReward, 0);
    //     uint ldoReward = vaultUsdc.getPoolExtraPendingReward();
    //     // console.log(ldoReward);
    //     assertEq(ldoReward, 0); // no ldo reward currently
    //     // assume bal, aura & ldo > 1 ether
    //     deal(address(bal), address(vaultUsdc), 1.1 ether);
    //     deal(address(aura), address(vaultUsdc), 1.1 ether);
    //     hoax(0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c);
    //     ldo.transfer(address(vaultUsdc), 1.1 ether);
    //     // harvest
    //     vaultUsdc.harvest();
    //     // assertion check
    //     assertEq(bal.balanceOf(address(vaultUsdc)), 0);
    //     assertEq(aura.balanceOf(address(vaultUsdc)), 0);
    //     assertEq(ldo.balanceOf(address(vaultUsdc)), 0);
    //     assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
    //     // console.log(aToken.balanceOf(address(vaultUsdc)));
    //     assertGt(aToken.balanceOf(address(vaultUsdc)), 0);
    //     assertGt(vaultUsdc.accRewardPerlpToken(), 0);
    //     assertGt(vaultUsdc.lastATokenAmt(), 0);
    //     assertGt(vaultUsdc.accRewardTokenAmt(), 0);
    //     // console.log(vaultUsdc.getUserPendingReward(address(this)));
    //     assertGt(vaultUsdc.getUserPendingReward(address(this)), 0);
    //     // Assume aToken increase
    //     hoax(0x68B1B65F3792ed4179b68A657f3dec71A69ead79);
    //     aToken.transfer(address(vaultUsdc), 1e6);
    //     uint accRewardPerlpToken = vaultUsdc.accRewardPerlpToken();
    //     uint lastATokenAmt = vaultUsdc.lastATokenAmt();
    //     uint userPendingVault = vaultUsdc.getUserPendingReward(address(this));
    //     vaultUsdc.harvest();
    //     assertGt(vaultUsdc.accRewardPerlpToken(), accRewardPerlpToken);
    //     assertGt(vaultUsdc.lastATokenAmt(), lastATokenAmt);
    //     assertGt(vaultUsdc.getUserPendingReward(address(this)), userPendingVault);
    // }

    // function testClaim() public {
    //     testHarvest();
    //     // record variable before claim
    //     uint userPendingReward = vaultUsdc.getUserPendingReward(address(this));
    //     // claim
    //     vaultUsdc.claim();
    //     // assertion check
    //     assertEq(usdc.balanceOf(address(this)), userPendingReward);
    //     assertLe(vaultUsdc.lastATokenAmt(), 1);
    //     assertLe(aToken.balanceOf(address(vaultUsdc)), 1);
    //     (, uint rewardStartAt) = vaultUsdc.userInfo(address(this));
    //     assertGt(rewardStartAt, 0);
    // }

    // function testPauseContract() public {
    //     // Pause contract and test deposit
    //     hoax(owner);
    //     vaultUsdc.pauseContract();
    //     vm.expectRevert(bytes("Pausable: paused"));
    //     vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
    //     // Unpause contract and test deposit
    //     hoax(owner);
    //     vaultUsdc.unPauseContract();
    //     vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
    //     vm.roll(block.number + 1);
    //     // Pause contract and test withdraw
    //     hoax(owner);
    //     vaultUsdc.pauseContract();
    //     vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)), 0);
    // }

    // function testUpgrade() public {
    //     PbAuraStable vaultImpl = new PbAuraStable();
    //     hoax(owner);
    //     vaultUsdc.upgradeTo(address(vaultImpl));
    // }

    // function testSetter() public {
    //     startHoax(owner);
    //     vaultUsdc.setYieldFeePerc(1000);
    //     assertEq(vaultUsdc.yieldFeePerc(), 1000);
    //     vaultUsdc.setTreasury(address(1));
    //     assertEq(vaultUsdc.treasury(), address(1));
    // }

    // function testAuthorization() public {
    //     assertEq(vaultUsdc.owner(), owner);
    //     // TransferOwnership
    //     startHoax(owner);
    //     vaultUsdc.transferOwnership(address(1));
    //     // Vault
    //     vm.expectRevert(bytes("Initializable: contract is already initialized"));
    //     vaultUsdc.initialize(0, IERC20Upgradeable(address(0)));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUsdc.pauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUsdc.unPauseContract();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUsdc.upgradeTo(address(0));
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUsdc.setYieldFeePerc(0);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     vaultUsdc.setTreasury(address(0));
    // }

    // function _getAssets() private view returns (address[] memory assets) {
    //     assets = new address[](2);
    //     assets[0] = address(wsteth);
    //     assets[1] = address(weth);
    // }

    function _getSwaps(uint amount, bytes32 poolId0, bytes32 poolId1) private pure returns (IBalancer.BatchSwapStep[] memory swaps) {
        swaps = new IBalancer.BatchSwapStep[](2);
        swaps[0] = IBalancer.BatchSwapStep({
            poolId: poolId0,
            assetInIndex: 0, // asset in out index follow assets above
            assetOutIndex: 1,
            amount: amount,
            userData: ""
        });
        swaps[1] = IBalancer.BatchSwapStep({
            poolId: poolId1,
            assetInIndex: 1,
            assetOutIndex: 2,
            amount: 0,
            userData: ""
        });
    }

    function _getFunds() private view returns (IBalancer.FundManagement memory funds) {
        funds = IBalancer.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this),
            toInternalBalance: false
        });
    }
    
    receive() external payable {}
}
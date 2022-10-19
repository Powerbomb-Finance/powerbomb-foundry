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

        // withdraw usdt
        assets[1] = address(bbaUsdt);
        assets[2] = address(usdt);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWbtc.getUserBalance(address(this)) / 2,
                bbaUsdPoolId,
                bbaUsdtPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWbtc.withdraw(usdt, vaultWbtc.getUserBalance(address(this)) / 2, amountOut * 99 / 100);

        // withdraw usdc
        assets[1] = address(bbaUsdc);
        assets[2] = address(usdc);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWeth.getUserBalance(address(this)) / 2,
                bbaUsdPoolId,
                bbaUsdcPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWeth.withdraw(usdc, vaultWeth.getUserBalance(address(this)) / 2, amountOut * 99 / 100);

        // withdraw dai
        assets[1] = address(bbaDai);
        assets[2] = address(dai);
        assetDeltas = balancer.queryBatchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            _getSwaps(
                vaultWbtc.getUserBalance(address(this)),
                bbaUsdPoolId,
                bbaDaiPoolId
            ),
            assets,
            funds
        );
        amountOut = uint(-assetDeltas[2]);
        vaultWbtc.withdraw(dai, vaultWbtc.getUserBalance(address(this)), amountOut * 99 / 100);

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
        assertEq(vaultWeth.getAllPool(), 0);
        assertEq(vaultWeth.getAllPoolInUSD(), 0);
        assertEq(vaultWeth.getUserBalance(address(this)), 0);
        assertEq(vaultWeth.getUserBalanceInUSD(address(this)), 0);
        // console.log(usdc.balanceOf(address(this)));
        assertGt(usdc.balanceOf(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(usdt.balanceOf(address(vaultWeth)), 0);
        assertEq(dai.balanceOf(address(vaultWeth)), 0);
        assertEq(lpToken.balanceOf(address(vaultWeth)), 0);
        (_lpTokenAmt, rewardStartAt) = vaultWeth.userInfo(address(this));
        assertEq(_lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);

        uint balReward;
        uint auraReward;
        // check pending reward
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

        // assume bal & aura > 1 ether
        deal(address(bal), address(vaultWbtc), 1.1 ether);
        deal(address(aura), address(vaultWbtc), 1.1 ether);
        deal(address(bal), address(vaultWeth), 1.1 ether);
        deal(address(aura), address(vaultWeth), 1.1 ether);

        // harvest
        vaultWbtc.harvest();
        vaultWeth.harvest();

        uint accRewardPerlpToken;
        uint lastATokenAmt;
        uint userPendingVault;
        // assertion check
        // vaultWbtc
        assertEq(bal.balanceOf(address(vaultWbtc)), 0);
        assertEq(aura.balanceOf(address(vaultWbtc)), 0);
        assertEq(wbtc.balanceOf(address(vaultWbtc)), 0);
        assertGt(aWbtc.balanceOf(address(vaultWbtc)), 0);
        assertGt(vaultWbtc.accRewardPerlpToken(), 0);
        assertGt(vaultWbtc.lastATokenAmt(), 0);
        assertGt(vaultWbtc.accRewardTokenAmt(), 0);
        // console.log(vaultWbtc.getUserPendingReward(address(this)));
        assertGt(vaultWbtc.getUserPendingReward(address(this)), 0);
        // Assume aToken increase
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
        assertEq(weth.balanceOf(address(vaultWeth)), 0);
        assertGt(aWeth.balanceOf(address(vaultWeth)), 0);
        assertGt(vaultWeth.accRewardPerlpToken(), 0);
        assertGt(vaultWeth.lastATokenAmt(), 0);
        assertGt(vaultWeth.accRewardTokenAmt(), 0);
        // console.log(vaultWeth.getUserPendingReward(address(this)));
        assertGt(vaultWeth.getUserPendingReward(address(this)), 0);
        // Assume aToken increase
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
        // assertion check
        assertEq(wbtc.balanceOf(address(this)), userPendingRewardWbtc);
        assertEq(weth.balanceOf(address(this)), userPendingRewardWeth);
        assertLe(vaultWbtc.lastATokenAmt(), 2);
        assertLe(vaultWeth.lastATokenAmt(), 2);
        assertLe(aWbtc.balanceOf(address(vaultWbtc)), 2);
        assertLe(aWeth.balanceOf(address(vaultWeth)), 2);
        uint rewardStartAt;
        (, rewardStartAt) = vaultWbtc.userInfo(address(this));
        assertGt(rewardStartAt, 0);
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
        vaultWbtc.deposit(dai, 1 ether, 0);
        vm.expectRevert(bytes("Pausable: paused"));
        vaultWeth.deposit(dai, 1 ether, 0);
        // Unpause contract and test deposit
        vm.startPrank(owner);
        vaultWbtc.unPauseContract();
        vaultWeth.unPauseContract();
        vm.stopPrank();
        deal(address(dai), address(this), 2 ether);
        dai.approve(address(vaultWbtc), type(uint).max);
        dai.approve(address(vaultWeth), type(uint).max);
        vaultWbtc.deposit(dai, 1 ether, 0);
        vaultWeth.deposit(dai, 1 ether, 0);
        vm.roll(block.number + 1);
        // Pause contract and test withdraw
        vm.startPrank(owner);
        vaultWbtc.pauseContract();
        vaultWeth.pauseContract();
        vm.stopPrank();
        vaultWbtc.withdraw(dai, vaultWbtc.getUserBalance(address(this)), 0);
        vaultWeth.withdraw(dai, vaultWeth.getUserBalance(address(this)), 0);
    }

    function testUpgrade() public {
        PbAuraStable vaultImpl = new PbAuraStable();
        startHoax(owner);
        vaultWbtc.upgradeTo(address(vaultImpl));
        vaultWeth.upgradeTo(address(vaultImpl));
    }

    function testSetter() public {
        startHoax(owner);
        vaultWbtc.setYieldFeePerc(1000);
        assertEq(vaultWbtc.yieldFeePerc(), 1000);
        vaultWbtc.setTreasury(address(1));
        assertEq(vaultWbtc.treasury(), address(1));
        vaultWeth.setYieldFeePerc(1000);
        assertEq(vaultWeth.yieldFeePerc(), 1000);
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
    }

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
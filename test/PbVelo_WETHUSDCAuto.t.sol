// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/PbVeloAuto.sol";
import "../src/PbVeloProxy.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IChainLink.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbVeloTest_WETHUSDCAuto is Test {
    PbVeloAuto vault;
    IWETH WETH = IWETH(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IERC20Upgradeable token0;
    IERC20Upgradeable token1;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable rewardToken;
    IRouter router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    function setUp() public {
        vault = new PbVeloAuto();
        PbVeloProxy proxy = new PbVeloProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address,address,address,address,address,address)")),
                address(VELO), // _VELO
                0xE2CEc8aB811B648bA7B1691Ce08d5E800Dd0a60a, // _gauge
                address(0), // _rewardToken
                address(0), // _lendingPool
                address(router), // _router
                address(WETH), // _WETH
                0x13e3Ee699D1909E989722E753853AE30b17e08c5, // _WETHPriceFeed
                address(1) // _treasury
            )
        );
        vault = PbVeloAuto(payable(address(proxy)));

        token0 = IERC20Upgradeable(vault.token0()); // WETH
        token1 = IERC20Upgradeable(vault.token1()); // USDC
        lpToken = IERC20Upgradeable(vault.lpToken());
    }

    function testDeposit() public {
        // Deposit token0
        deal(address(token0), address(this), 10 ether);
        token0.approve(address(vault), type(uint).max);
        (uint amountOut,) = router.getAmountOut(token0.balanceOf(address(this)) / 2, address(token0), address(token1));
        vault.deposit(token0, token0.balanceOf(address(this)), amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this)));
        // console.log(token1.balanceOf(address(this)));

        // Deposit token1
        deal(address(token1), address(this), 10_000e6);
        token1.approve(address(vault), type(uint).max);
        (amountOut,) = router.getAmountOut(token1.balanceOf(address(this)) / 2, address(token1), address(token0));
        vault.deposit(token1, token1.balanceOf(address(this)), amountOut * 95 / 100);
        // console.log(token0.balanceOf(address(this)));
        // console.log(token1.balanceOf(address(this)));

        // Deposit ETH
        (amountOut,) = router.getAmountOut(10 ether / 2, address(token0), address(token1));
        vault.deposit{value: 10 ether}(token0, 10 ether, amountOut * 95 / 100);

        // Deposit LP
        deal(address(lpToken), address(this), 0.000001 ether);
        lpToken.approve(address(vault), type(uint).max);
        vault.deposit(lpToken, lpToken.balanceOf(address(this)), 0);

        uint userBalance = vault.getUserBalance(address(this));
        assertGt(userBalance, 0);
        // console.log(userBalance);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(address(this));
        assertGt(userBalanceInUSD, 0);
        // console.log(userBalanceInUSD);
        uint pricePerFullShareInUSD = vault.getPricePerFullShareInUSD();
        assertGt(pricePerFullShareInUSD, 0);
        // console.log(pricePerFullShareInUSD);
        uint allPool = vault.getAllPool();
        assertGt(allPool, 0);
        // console.log(allPool);
        uint allPoolInUSD = vault.getAllPoolInUSD();
        assertGt(allPoolInUSD, 0);
        // console.log(allPoolInUSD);
        uint totalSupply = vault.totalSupply();
        assertGt(totalSupply, 0);
        // console.log(totalSupply);
        assertEq(userBalance, allPool);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint userBalance = vault.getUserBalance(address(this)) / 4;

        // Withdraw token0
        (uint amount0, uint amount1) = router.quoteRemoveLiquidity(address(token0), address(token1), vault.stable(), userBalance);
        (uint amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        uint token0Bef = token0.balanceOf(address(this));
        vault.withdraw(token0, userBalance, amountOut * 95 / 100);
        assertGt(token0.balanceOf(address(this)), token0Bef);

        // Withdraw token1
        (amountOut,) = router.getAmountOut(amount0, address(token0), address(token1));
        uint token1Bef = token1.balanceOf(address(this));
        vault.withdraw(token1, userBalance, amountOut * 95 / 100);
        assertGt(token1.balanceOf(address(this)), token1Bef);

        // Withdraw ETH
        (amountOut,) = router.getAmountOut(amount1, address(token1), address(token0));
        uint ETHBef = address(this).balance;
        vault.withdrawETH(token0, userBalance, amountOut * 95 / 100);
        assertGt(address(this).balance, ETHBef);

        // withdraw LP
        uint lpTokenBef = lpToken.balanceOf(address(this));
        vault.withdraw(lpToken, userBalance, 0);
        assertGt(lpToken.balanceOf(address(this)), lpTokenBef);

        userBalance = vault.getUserBalance(address(this));
        assertEq(userBalance, 1);
        // console.log(userBalance);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(address(this));
        assertEq(userBalanceInUSD, 0);
        // console.log(userBalanceInUSD);
        uint allPool = vault.getAllPool();
        assertEq(allPool, 1);
        // console.log(allPool);
        uint allPoolInUSD = vault.getAllPoolInUSD();
        assertEq(allPoolInUSD, 0);
        // console.log(allPoolInUSD);
        uint totalSupply = vault.totalSupply();
        assertLe(totalSupply, 1);
        // console.log(totalSupply);
    }

    receive() external payable {}

    function testHarvest() public {
        testDeposit();
        uint WETHBef = WETH.balanceOf(address(1));
        uint allPoolBef = vault.getAllPool();
        // Assume reward
        deal(address(VELO), address(vault), 1000 ether);
        // Harvest
        vault.harvest();
        // Assertion check
        assertGt(WETH.balanceOf(address(1)), WETHBef);
        assertGt(vault.getAllPool(), allPoolBef);
    }

    function testAutocompound() public {
        deal(address(token0), address(this), 1 ether);
        token0.approve(address(vault), type(uint).max);
        vault.deposit(token0, token0.balanceOf(address(this)), 0);
        deal(address(VELO), address(vault), 1000 ether);
        vault.harvest();
        vm.roll(block.number + 1);
        vault.withdraw(token0, vault.getUserBalance(address(this)), 0);
        assertGt(token0.balanceOf(address(this)), 1 ether);        
    }

    function testDistributeEvenly() public {
        // address(1) deposit
        hoax(address(1));
        vault.deposit{value: 1 ether}(token0, 1 ether, 0);
        deal(address(VELO), address(vault), 1000 ether);
        // Harvest
        vault.harvest();
        // address(2) deposit
        hoax(address(2));
        vault.deposit{value: 1 ether}(token0, 1 ether, 0);
        deal(address(VELO), address(vault), 1000 ether);
        // Harvest
        vault.harvest();
        // address(3) deposit
        hoax(address(3));
        vault.deposit{value: 1 ether}(token0, 1 ether, 0);
        deal(address(VELO), address(vault), 1000 ether);
        // Harvest
        vault.harvest();
        // Add 1 block
        vm.roll(block.number + 1);
        // address(1) withdraw
        uint addr1Share = vault.getUserBalance(address(1));
        hoax(address(1));
        vault.withdraw(token0, addr1Share, 0);
        // address(2) withdraw
        uint addr2Share = vault.getUserBalance(address(2));
        hoax(address(2));
        vault.withdraw(token0, addr2Share, 0);
        // address(3) withdraw
        uint addr3Share = vault.getUserBalance(address(3));
        hoax(address(3));
        vault.withdraw(token0, addr3Share, 0);
        // Assertion check
        uint addr1Bal = token0.balanceOf(address(1));
        uint addr2Bal = token0.balanceOf(address(2));
        uint addr3Bal = token0.balanceOf(address(3));
        assertGt(addr1Bal, addr2Bal);
        assertGt(addr1Bal, addr3Bal);
        assertGt(addr2Bal, addr3Bal);
    }

    function testPauseContract() public {
        // Pause contract
        vault.pauseContract();
        // Test deposit
        vm.expectRevert(bytes("Pausable: paused"));
        vault.deposit(WETH, 1 ether, 0);
        // Unpause contract
        vault.unpauseContract();
        // Test deposit again
        deal(address(WETH), address(this), 1 ether);
        WETH.approve(address(vault), type(uint).max);
        vault.deposit(WETH, 1 ether, 0);
    }

    function testAuthorization() public {
        vault.transferOwnership(address(1));
        assertEq(vault.owner(), address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setTreasury(address(this));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vault.setYieldFeePerc(0);
    }

    function testUpgrade() public {
        PbVelo vault_ = new PbVelo();
        vault.upgradeTo(address(vault_));
    }
}

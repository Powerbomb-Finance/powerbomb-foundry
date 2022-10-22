// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbCvxSteth.sol";
import "../interface/IPool.sol";

contract PbCvxStethTest is Test {

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable crv = IERC20Upgradeable(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Upgradeable cvx = IERC20Upgradeable(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20Upgradeable steth = IERC20Upgradeable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20Upgradeable ldo = IERC20Upgradeable(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
    PbCvxSteth vaultUsdc;
    IPool pool;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable aToken;
    // address owner = address(this);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // Deploy implementation contract
        // PbCvxSteth vaultImpl = new PbCvxSteth();

        // // Deploy usdc reward proxy contract
        // PbProxy proxy = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(uint256,address,address)")),
        //         25,
        //         0xDC24316b9AE028F1497c275EB9192a3Ea0f67022,
        //         address(usdc)
        //     )
        // );
        // vaultUsdc = PbCvxSteth(payable(address(proxy)));
        vaultUsdc = PbCvxSteth(payable(0x0Aac6e405dD7355c728ce550A452Adda28f8b522));

        pool = vaultUsdc.pool();
        lpToken = vaultUsdc.lpToken();
        aToken = vaultUsdc.aToken();
    }

    // function test() public {
    //     vaultUsdc.deposit{value: 10 ether}(weth, 10 ether, 0);
    //     skip(864000);
    //     // vaultUsdc.getPoolPendingReward();
    //     deal(address(crv), address(vaultUsdc), 1.1 ether);
    //     deal(address(cvx), address(vaultUsdc), 1.1 ether);
    //     hoax(0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c);
    //     ldo.transfer(address(vaultUsdc), 1.1 ether);
    //     vaultUsdc.deposit{value: 10 ether}(weth, 10 ether, 0);
    //     // vaultUsdc.harvest();
    //     // vaultUsdc.claim();
    //     vm.roll(block.number + 1);
    //     vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)), 0);
    // }

    function testDeposit() public {
        // Deposit native eth
        uint[2] memory amounts = [10 ether, uint(0)];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vaultUsdc.deposit{value: 10 ether}(weth, 10 ether, amountOut * 99 / 100);
        // Deposit steth
        address stethHolder = 0x1982b2F5814301d4e9a8b0201555376e62F82428;
        hoax(stethHolder);
        steth.transfer(address(this), 10 ether);
        amounts = [uint(0), 10 ether];
        amountOut = pool.calc_token_amount(amounts, true);
        steth.approve(address(vaultUsdc), type(uint).max);
        vaultUsdc.deposit(steth, 10 ether, amountOut * 99 / 100);
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
        assertEq(steth.balanceOf(address(this)), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function testWithdraw() public {
        testDeposit();
        vm.roll(block.number + 1);
        uint balBef = address(this).balance;
        // withdraw native eth
        uint amountOut = pool.calc_withdraw_one_coin(vaultUsdc.getUserBalance(address(this)) / 3, int128(0));
        vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)) / 3, amountOut * 99 / 100);
        // withdraw steth
        amountOut = pool.calc_withdraw_one_coin(vaultUsdc.getUserBalance(address(this)) / 2, int128(1));
        vaultUsdc.withdraw(steth, vaultUsdc.getUserBalance(address(this)) / 2, amountOut * 99 / 100);
        // withdraw lp token
        vaultUsdc.withdraw(lpToken, vaultUsdc.getUserBalance(address(this)), 0);
        // assertion check
        assertEq(vaultUsdc.getAllPool(), 0);
        assertEq(vaultUsdc.getAllPoolInUSD(), 0);
        assertEq(vaultUsdc.getUserBalance(address(this)), 0);
        assertEq(vaultUsdc.getUserBalanceInUSD(address(this)), 0);
        // console.log(address(this).balance - balBef);
        assertGt(address(this).balance, balBef);
        // console.log(steth.balanceOf(address(this)));
        assertGt(steth.balanceOf(address(this)), 0);
        // console.log(lpToken.balanceOf(address(this)));
        assertGt(lpToken.balanceOf(address(this)), 0);
        assertEq(address(vaultUsdc).balance, 0);
        assertEq(steth.balanceOf(address(vaultUsdc)), 0);
        assertEq(lpToken.balanceOf(address(vaultUsdc)), 0);
        (uint lpTokenAmt, uint rewardStartAt) = vaultUsdc.userInfo(address(this));
        assertEq(lpTokenAmt, 0);
        assertEq(rewardStartAt, 0);
    }

    function testHarvest() public {
        testDeposit();
        skip(864000);
        // check pending reward
        (uint crvReward, uint cvxReward) = vaultUsdc.getPoolPendingReward();
        // console.log(crvReward);
        // console.log(cvxReward);
        assertGt(crvReward, 0);
        assertGt(cvxReward, 0); 
        uint ldoReward = vaultUsdc.getPoolExtraPendingReward();
        // console.log(ldoReward);
        assertGt(ldoReward, 0);
        // assume crv & cvx > 1 ether
        deal(address(crv), address(vaultUsdc), 1 ether);
        deal(address(cvx), address(vaultUsdc), 1 ether);
        // harvest
        vaultUsdc.harvest();
        // assertion check
        assertEq(crv.balanceOf(address(vaultUsdc)), 0);
        assertEq(cvx.balanceOf(address(vaultUsdc)), 0);
        assertEq(ldo.balanceOf(address(vaultUsdc)), 0);
        assertEq(usdc.balanceOf(address(vaultUsdc)), 0);
        assertGt(aToken.balanceOf(address(vaultUsdc)), 0);
        assertGt(vaultUsdc.accRewardPerlpToken(), 0);
        assertGt(vaultUsdc.lastATokenAmt(), 0);
        assertGt(vaultUsdc.accRewardTokenAmt(), 0);
        // console.log(vaultUsdc.getUserPendingReward(address(this)));
        assertGt(vaultUsdc.getUserPendingReward(address(this)), 0);
        // console.log(token);
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
        PbCvxSteth vaultImpl = new PbCvxSteth();
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
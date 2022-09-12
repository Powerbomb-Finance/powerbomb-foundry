// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "forge-std/Test.sol";
import "../src/PengTogether.sol";
import "../src/FarmCurve.sol";
import "../src/PbProxy.sol";

contract PengTogetherTest is Test {
    IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IWETH weth = IWETH(0x4200000000000000000000000000000000000006);
    IZap zap = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    address reward = address(1);
    address treasury = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    PengTogether vault;
    FarmCurve farm;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // farm = new FarmCurve();
        // PbProxy proxy = new PbProxy(
        //     address(farm),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // farm = FarmCurve(payable(address(proxy)));
        farm = FarmCurve(payable(0xB68F3D8E341B88df22a73034DbDE3c888f4bE9DE));

        // vault = new PengTogether();
        // proxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(farm)
        //     )
        // );
        // vault = PengTogether(address(proxy));
        vault = PengTogether(0x8EdF0c0f9C56B11A5bE56CB816A2e57c110f44b1);

        // farm.setVault(address(vault));
        hoax(owner);
        farm.setReward(reward);
    }

    function testDepositPlaceSeat2Account() public {
        deal(address(usdc), address(1), 1000e6);
        deal(address(usdc), address(2), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        vault.placeSeat();
        vm.stopPrank();

        vm.startPrank(address(2));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        vault.placeSeat();
        vm.stopPrank();

        (address user, uint from, uint to) = vault.seats(0);
        assertEq(user, address(1));
        assertEq(from, 0);
        assertEq(to, 9);
        assertEq(vault.getSeatOwner(0), address(1));
        assertEq(vault.getSeatOwner(4), address(1));
        assertEq(vault.getSeatOwner(9), address(1));

        (user, from, to) = vault.seats(1);
        assertEq(user, address(2));
        assertEq(from, 10);
        assertEq(to, 19);
        assertEq(vault.getSeatOwner(10), address(2));
        assertEq(vault.getSeatOwner(16), address(2));
        assertEq(vault.getSeatOwner(19), address(2));

        (uint depositBal,, uint ticketBal, uint lastUpdateTimestamp) = vault.userInfo(address(1));
        assertEq(depositBal, 1000e6);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        (depositBal,, ticketBal, lastUpdateTimestamp) = vault.userInfo(address(2));
        assertEq(depositBal, 1000e6);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        assertEq(vault.getUserTotalSeats(address(1)), 10);
        assertEq(vault.getUserAvailableTickets(address(1)), 10);
        assertEq(vault.getUserTotalSeats(address(2)), 10);
        assertEq(vault.getUserAvailableTickets(address(2)), 0);
    }

    function testDeposit2TimesPlaceSeat() public {
        deal(address(usdc), address(1), 1500e6);
        
        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        vault.deposit(usdc, 500e6, 0);
        skip(3600);
        vm.stopPrank();

        (uint depositBal,, uint ticketBal, uint lastUpdateTimestamp) = vault.userInfo(address(1));
        assertEq(depositBal, 1500e6);
        assertEq(ticketBal, 10);
        assertGt(lastUpdateTimestamp, 0);

        assertEq(vault.getUserTotalSeats(address(1)), 0);
        assertEq(vault.getUserAvailableTickets(address(1)), 25);

        hoax(address(1));
        vault.placeSeat();

        (address user, uint from, uint to) = vault.seats(0);
        assertEq(user, address(1));
        assertEq(from, 0);
        assertEq(to, 24);

        assertEq(vault.getUserTotalSeats(address(1)), 25);
        assertEq(vault.getUserAvailableTickets(address(1)), 0);
    }

    function testDeposit2AccountPlaceSeat() public {
        deal(address(usdc), address(1), 500e6);
        deal(address(usdc), address(2), 1000e6);
        
        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 500e6, 0);
        skip(3600);
        vm.stopPrank();

        vm.startPrank(address(2));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        vm.stopPrank();

        assertEq(vault.getUserAvailableTickets(address(1)), vault.getUserAvailableTickets(address(2)));

        hoax(address(1));
        vault.placeSeat();
        hoax(address(2));
        vault.placeSeat();

        (address user, uint from, uint to) = vault.seats(0);
        assertEq(user, address(1));
        assertEq(from, 0);
        assertEq(to, 9);

        (user, from, to) = vault.seats(1);
        assertEq(user, address(2));
        assertEq(from, 10);
        assertEq(to, 19);

        assertEq(vault.getUserTotalSeats(address(1)), vault.getUserTotalSeats(address(1)));
    }

    function testDeposit5TimesNoPlaceSeat() public {
        deal(address(usdc), address(1), 5000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vm.stopPrank();

        assertEq(vault.getUserAvailableTickets(address(1)), 1200 + 960 + 720 + 480 + 240);
        (uint depositBal,, uint ticketBal,) = vault.userInfo(address(1));
        assertEq(depositBal, 5000e6);
        assertEq(ticketBal, 2400);
    }

    function testDepositPlaceSeat5Times() public {
        deal(address(usdc), address(1), 5000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.placeSeat();
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.placeSeat(); // (240*2) + (240*1) - 240 = 480
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.placeSeat(); // (240*4) + (240*3) + (240*2) + (240*1) - 240 - 480 = 1680
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vm.stopPrank();

        assertEq(vault.getUserAvailableTickets(address(1)), 1200);

        (, uint from, uint to) = vault.seats(0);
        assertEq(from, 0);
        assertEq(to, 239);

        (, from, to) = vault.seats(1);
        assertEq(from, 240);
        assertEq(to, 719);

        (, from, to) = vault.seats(2);
        assertEq(from, 720);
        assertEq(to, 2399);
    }

    function testRestartRound() public {
        deal(address(usdc), address(1), 500e6);
        deal(address(usdc), address(2), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 500e6, 0);
        skip(86400);
        vm.stopPrank();

        vm.startPrank(address(2));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vm.stopPrank();

        address[] memory users = new address[](2);
        users[0] = address(1);
        users[1] = address(2);
        hoax(owner);
        vault.placeSeat{value: 0.1 ether}(users);

        vm.expectRevert("lucky draw in progress");
        hoax(address(1));
        vault.placeSeat();

        (, uint from, uint to) = vault.seats(0);
        assertEq(from, 0);
        assertEq(to, 239);

        (, from, to) = vault.seats(1);
        assertEq(from, 240);
        assertEq(to, 479);

        assertEq(vault.getUserAvailableTickets(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 240);
        assertEq(vault.getUserAvailableTickets(address(2)), 0);
        assertEq(vault.getUserTotalSeats(address(2)), 240);

        hoax(owner);
        vault.setWinnerAndRestartRound{value: 0.01 ether}(address(1));

        assertEq(vault.getSeatsLength(), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(2)), 0);

        skip(3600);
        assertEq(vault.getUserAvailableTickets(address(1)), 5);
        assertEq(vault.getUserTotalSeats(address(1)), 0);
        hoax(address(1));
        // test able to place seat
        vault.placeSeat();
        assertEq(vault.getUserAvailableTickets(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 5);
        (, from, to) = vault.seats(0);
        assertEq(from, 0);
        assertEq(to, 4);
    }

    function testDepositNotEnoughHour() public {
        deal(address(usdc), address(1), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 500e6, 0);
        skip(1800);
        vault.deposit(usdc, 500e6, 0);
        vm.stopPrank();

        assertEq(vault.getUserAvailableTickets(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 0);
    }

    function testDepositAndWithdraw() public {
        deal(address(usdc), address(this), 1000e6);
        usdc.approve(address(vault), type(uint).max);

        // deposit
        uint[4] memory amounts = [0, 0, uint(1000e6), 0];
        uint amountOut = zap.calc_token_amount(address(lpToken), amounts, true);
        vault.deposit(usdc, 1000e6, amountOut * 99 / 100);

        // assertion check
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(vault)), 0);
        assertEq(usdc.balanceOf(address(farm)), 0);
        assertEq(lpToken.balanceOf(address(farm)), 0);
        assertGt(vault.getAllPoolInUSD(), 0);
        assertGt(vault.getUserBalance(address(this)), 0);
        assertGt(vault.getUserBalanceInUSD(address(this)), 0);
        assertEq(vault.getUserDepositBalance(address(this)), 1000e6);

        vm.roll(block.number + 1);

        // withdraw
        uint withdrawPerc = 1000e6 * 1e18 / vault.getUserDepositBalance(address(this));
        uint lpTokenAmt = vault.getUserBalance(address(this)) * withdrawPerc / 1e18;
        amountOut = zap.calc_withdraw_one_coin(address(lpToken), lpTokenAmt, 2);
        vault.withdraw(usdc, 1000e6, amountOut * 99 / 100);
        // console.log(usdc.balanceOf(address(this))); // 999.331504

        // assertion check
        assertGt(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(vault)), 0);
        assertEq(usdc.balanceOf(address(farm)), 0);
        assertEq(lpToken.balanceOf(address(farm)), 0);
        assertEq(vault.getAllPoolInUSD(), 0);
        assertEq(vault.getUserBalance(address(this)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this)), 0);
        assertEq(vault.getUserDepositBalance(address(this)), 0);
    }

    function testWithdrawAll() public {
        deal(address(usdc), address(1), 2000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);

        vm.roll(block.number + 1);
        // 1st deposit earn 240 tickets
        // 2nd deposit until withdraw should earn another 480 tickets
        // but since it is withdrawal, ticket calculate by balance left after withdrawal
        // so 24 hours * $1000 = 240 tickets
        // so total 240 + 240 = 480 tickets
        vault.withdraw(usdc, 1000e6, 0);
        vm.stopPrank();

        // console.log(usdc.balanceOf(address(1))); // 1998.691931
        assertEq(vault.getUserAvailableTickets(address(1)), 480);
        assertEq(vault.getUserTotalSeats(address(1)), 0);

        address[] memory users = new address[](1);
        users[0] = address(1);
        hoax(owner);
        vault.placeSeat{value: 0.1 ether}(users);

        assertEq(vault.getUserAvailableTickets(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 480);
    }

    function testHarvest() public {
        deal(address(usdc), address(this), 100000e6);
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 100000e6, 0);

        skip(864000);
        uint wethBef = weth.balanceOf(treasury);
        // farm.getPoolPendingReward(); // only can test with view
        vm.recordLogs();
        hoax(owner);
        farm.harvest{value: 0.05 ether}();

        assertEq(crv.balanceOf(address(farm)), 0);
        assertEq(op.balanceOf(address(farm)), 0);
        assertEq(weth.balanceOf(address(farm)), 0);
        assertEq(address(farm).balance, 0);
        assertGt(weth.balanceOf(treasury), wethBef);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (uint crvAmt, uint opAmt, uint wethAmt, uint fee) = abi.decode(entries[24].data, (uint, uint, uint, uint));
        // console.log(crvAmt); // 39471738946279452263
        // console.log(opAmt); // 35611387480280085704
        // console.log(wethAmt); // 48835593914989837
        // console.log(fee); // 5426177101665537
        assertGt(crvAmt, 0);
        assertGt(opAmt, 0);
        assertGt(wethAmt, 0);
        assertGt(fee, 0);
    }

    function testGlobalVariable() public {
        // vault
        assertEq(vault.getSeatsLength(), 0);
        assertEq(vault.getTotalSeats(), 0);
        assertEq(vault.luckyDrawInProgress(), false);
        assertEq(vault.admin(), owner);
        assertEq(address(vault.farm()), address(farm));

        // farm
        assertEq(farm.admin(), owner);
        assertEq(farm.vault(), address(vault));
        assertEq(farm.reward(), reward);
        assertEq(farm.treasury(), treasury);
        assertEq(farm.yieldFeePerc(), 1000);
    }

    function testSetter() public {
        startHoax(owner);
        // vault
        vault.setFarm(IFarm(address(1)));
        assertEq(address(vault.farm()), address(1));
        vault.setAdmin(address(1));
        assertEq(vault.admin(), address(1));

        // farm
        farm.setAdmin(address(1));
        assertEq(farm.admin(), address(1));
        farm.setVault(address(1));
        assertEq(farm.vault(), address(1));
        farm.setReward(address(1));
        assertEq(farm.reward(), address(1));
        farm.setTreasury(address(1));
        assertEq(farm.treasury(), address(1));
        farm.setYieldFeePerc(2000);
        assertEq(farm.yieldFeePerc(), 2000);
    }

    function testAuthorization() public {
        // vault
        assertEq(vault.owner(), owner);
        vm.startPrank(owner);
        vault.setAdmin(address(1));
        vault.transferOwnership(address(1));
        vm.stopPrank();
        vm.expectRevert("only authorized");
        vault.placeSeat(new address[](1));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        vault.unPauseContract();
        vm.expectRevert("only authorized");
        vault.setWinnerAndRestartRound(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setFarm(IFarm(address(0)));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setAdmin(address(0));

        // farm
        assertEq(farm.owner(), owner);
        vm.startPrank(owner);
        farm.setAdmin(address(1));
        farm.transferOwnership(address(1));
        vm.stopPrank();
        vm.expectRevert("only vault");
        farm.deposit(0, 0);
        vm.expectRevert("only vault");
        farm.withdraw(0, 0);
        vm.expectRevert("only admin or owner");
        farm.harvest();
        vm.expectRevert("Ownable: caller is not the owner");
        farm.setAdmin(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        farm.setVault(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        farm.setReward(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        farm.setTreasury(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        farm.setYieldFeePerc(0);
    }

    receive() external payable {}
}

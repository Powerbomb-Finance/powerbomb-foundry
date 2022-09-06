// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "forge-std/Test.sol";
import "../src/PengTogether.sol";
import "../src/FarmCurve.sol";

contract PengTogetherTest is Test {
    IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    PengTogether vault;
    FarmCurve farm;

    function setUp() public {
        farm = new FarmCurve();
        farm.initialize();
        vault = new PengTogether();
        vault.initialize(IFarm(address(farm)));
        farm.setVault(address(vault));
    }

    function test1() public {
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

    function test2() public {
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

    function test3() public {
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

    function test4() public {
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

    function test5() public {
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
        vault.placeSeat(users);

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

        vault.setWinnerAndRestartRound{value: 1 ether}(address(1));

        assertEq(vault.getSeatsLength(), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(2)), 0);
    }

    function test7() public {
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

    function testWithdrawAll() public {
        deal(address(usdc), address(1), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vm.roll(block.number + 1);
        vault.withdraw(usdc, 1000e6, 0);
        vm.stopPrank();

        // console.log(usdc.balanceOf(address(1))); // 999.352449
        assertEq(vault.getUserAvailableTickets(address(1)), 240);
        assertEq(vault.getUserTotalSeats(address(1)), 0);

        address[] memory users = new address[](1);
        users[0] = address(1);
        vault.placeSeat(users);

        assertEq(vault.getUserAvailableTickets(address(1)), 0);
        assertEq(vault.getUserTotalSeats(address(1)), 240);
    }

    function testHarvest() public {
        deal(address(usdc), address(this), 100000e6);
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 100000e6, 0);

        skip(864000);
        farm.getPoolPendingReward();
        farm.harvest{value: 1 ether}();
    }

    receive() external payable {}
}

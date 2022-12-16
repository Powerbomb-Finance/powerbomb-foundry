// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "forge-std/Test.sol";
import "../src/PengTogether.sol";
import "../src/record.sol";
import "../src/PbProxy.sol";

contract PengTogetherTest is Test {
    IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IWETH weth = IWETH(0x4200000000000000000000000000000000000006);
    IZap zap = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    address reward = 0xF7A1f8918301D9C09105812eB045AA168aB3BFea;
    address dao = 0x28BCc4202cd179499bF618DBfd1bFE37278E1A12;
    address treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
    PengTogether vault;
    Record record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address helper = 0xCf91CDBB4691a4b912928A00f809f356c0ef30D6;

    function setUp() public {
        // record = new Record();
        // PbProxy proxy = new PbProxy(
        //     address(record),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // record = Record(address(proxy));
        record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d);
        Record recordImpl = new Record();
        hoax(owner);
        record.upgradeTo(address(recordImpl));

        // vault = new PengTogether();
        // proxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(record)
        //     )
        // );
        // vault = PengTogether(payable(address(proxy)));
        vault = PengTogether(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614));
        PengTogether vaultImpl = new PengTogether();
        hoax(owner);
        vault.upgradeTo(address(vaultImpl));

        // hoax(owner);
        // record.setVault(address(vault));
        // record.setDao(dao);
        // vault.setReward(reward);
        // vault.setHelper(helper);
    }

    // function test() public {
    //     address userAddr = 0xA21169327f599936C1a198bF5D2E7Cc89944cd88;
    //     // record.getUserTotalTickets(userAddr);
    //     // hoax(userAddr);
    //     // vault.deposit(usdc, 100e6, 0);
    //     console.log(record.getUserTotalTickets(userAddr));
    // }

    function testDepositPlaceSeat2Account() public {
        deal(address(usdc), address(1), 1000e6);
        deal(address(usdc), address(2), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        // vault.placeSeat();
        vm.stopPrank();

        vm.startPrank(address(2));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        // vault.placeSeat();
        vm.stopPrank();

        // (address user, uint from, uint to) = vault.seats(0);
        // assertEq(user, address(1));
        // assertEq(from, 0);
        // assertEq(to, 9);
        // assertEq(vault.getSeatOwner(0), address(1));
        // assertEq(vault.getSeatOwner(4), address(1));
        // assertEq(vault.getSeatOwner(9), address(1));

        // (user, from, to) = vault.seats(1);
        // assertEq(user, address(2));
        // assertEq(from, 10);
        // assertEq(to, 19);
        // assertEq(vault.getSeatOwner(10), address(2));
        // assertEq(vault.getSeatOwner(16), address(2));
        // assertEq(vault.getSeatOwner(19), address(2));

        (uint depositBal,, uint ticketBal, uint lastUpdateTimestamp) = record.userInfo(address(1));
        assertEq(depositBal, 1000e6);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        (depositBal,, ticketBal, lastUpdateTimestamp) = record.userInfo(address(2));
        assertEq(depositBal, 1000e6);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        assertEq(record.getUserTotalSeats(address(1)), 0);
        assertEq(record.getUserAvailableTickets(address(1)), 20);
        assertEq(record.getUserTotalSeats(address(2)), 0);
        assertEq(record.getUserAvailableTickets(address(2)), 10);
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

        (uint depositBal,, uint ticketBal, uint lastUpdateTimestamp) = record.userInfo(address(1));
        assertEq(depositBal, 1500e6);
        assertEq(ticketBal, 10);
        assertGt(lastUpdateTimestamp, 0);

        assertEq(record.getUserTotalSeats(address(1)), 0);
        assertEq(record.getUserAvailableTickets(address(1)), 25);

        // hoax(address(1));
        // vault.placeSeat();

        // (address user, uint from, uint to) = vault.seats(0);
        // assertEq(user, address(1));
        // assertEq(from, 0);
        // assertEq(to, 24);

        // assertEq(vault.getUserTotalSeats(address(1)), 25);
        // assertEq(vault.getUserAvailableTickets(address(1)), 0);
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

        assertEq(record.getUserAvailableTickets(address(1)), record.getUserAvailableTickets(address(2)));

        // hoax(address(1));
        // vault.placeSeat();
        // hoax(address(2));
        // vault.placeSeat();

        // (address user, uint from, uint to) = vault.seats(0);
        // assertEq(user, address(1));
        // assertEq(from, 0);
        // assertEq(to, 9);

        // (user, from, to) = vault.seats(1);
        // assertEq(user, address(2));
        // assertEq(from, 10);
        // assertEq(to, 19);

        assertEq(record.getUserTotalSeats(address(1)), record.getUserTotalSeats(address(1)));
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

        assertEq(record.getUserAvailableTickets(address(1)), 1200 + 960 + 720 + 480 + 240);
        (uint depositBal,, uint ticketBal,) = record.userInfo(address(1));
        assertEq(depositBal, 5000e6);
        assertEq(ticketBal, 2400);
    }

    function testDepositPlaceSeat5Times() public {
        deal(address(usdc), address(1), 5000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        // vault.placeSeat();
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        // vault.placeSeat(); // (240*2) + (240*1) - 240 = 480
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        // vault.placeSeat(); // (240*4) + (240*3) + (240*2) + (240*1) - 240 - 480 = 1680
        vault.deposit(usdc, 1000e6, 0);
        skip(86400);
        vm.stopPrank();

        assertEq(record.getUserAvailableTickets(address(1)), 3600);

        // (, uint from, uint to) = vault.seats(0);
        // assertEq(from, 0);
        // assertEq(to, 239);

        // (, from, to) = vault.seats(1);
        // assertEq(from, 240);
        // assertEq(to, 719);

        // (, from, to) = vault.seats(2);
        // assertEq(from, 720);
        // assertEq(to, 2399);
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
        record.placeSeat{value: 0.1 ether}(users);

        // vm.expectRevert("lucky draw in progress");
        // hoax(address(1));
        // vault.placeSeat();

        (, uint from, uint to) = record.seats(0);
        assertEq(from, 0);
        assertEq(to, 239);

        (, from, to) = record.seats(1);
        assertEq(from, 240);
        assertEq(to, 479);

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 240);
        assertEq(record.getUserAvailableTickets(address(2)), 0);
        assertEq(record.getUserTotalSeats(address(2)), 240);

        hoax(owner);
        record.setWinnerAndRestartRound{value: 0.01 ether}(address(1));

        assertEq(record.getSeatsLength(), 0);
        assertEq(record.getUserTotalSeats(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(2)), 0);
        assertEq(record.drawInProgress(), false);
        assertEq(record.totalSeatsAfterPlaceSeat(), 0);

        skip(3600);
        assertEq(record.getUserAvailableTickets(address(1)), 5);
        assertEq(record.getUserTotalSeats(address(1)), 0);
        // hoax(address(1));
        // // test able to place seat
        // vault.placeSeat();
        // assertEq(vault.getUserAvailableTickets(address(1)), 0);
        // assertEq(vault.getUserTotalSeats(address(1)), 5);
        // (, from, to) = vault.seats(0);
        // assertEq(from, 0);
        // assertEq(to, 4);
    }

    function testDepositNotEnoughHour() public {
        deal(address(usdc), address(1), 1000e6);

        vm.startPrank(address(1));
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 500e6, 0);
        skip(1800);
        vault.deposit(usdc, 500e6, 0);
        vm.stopPrank();

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 0);
    }

    function testDepositBalLessThan100WhenDraw() public {
        deal(address(usdc), address(this), 1000e6);
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 1000e6, 0);
        skip(3600);
        vm.roll(block.number + 1);
        vault.withdraw(usdc, 995e6, 0);

        assertEq(record.getUserAvailableTickets(address(this)), 10);

        // draw
        address[] memory users = new address[](1);
        users[0] = address(this);
        hoax(owner);
        record.placeSeat{value: 0.1 ether}(users);

        // assertion check
        assertEq(record.getUserAvailableTickets(address(this)), 0);
        assertEq(record.getUserTotalSeats(address(this)), 0);
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
        assertEq(lpToken.balanceOf(address(vault)), 0);
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
        assertEq(lpToken.balanceOf(address(vault)), 0);
        // assertEq(vault.getAllPoolInUSD(), 0);
        assertEq(vault.getUserBalance(address(this)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this)), 0);
        assertEq(vault.getUserDepositBalance(address(this)), 0);
    }

    function testDepositByHelper() public {
        // deposit, assume helper contract has 10000 usdc
        deal(address(usdc), helper, 10000e6);
        startHoax(helper);
        usdc.approve(address(vault), 10000e6);
        vault.depositByHelper(usdc, 10000e6, 0, address(this));
        vm.stopPrank();
        // assertion check
        assertEq(vault.getUserDepositBalance(address(this)), 10000e6);
        assertEq(usdc.balanceOf(address(vault)), 0);
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
        vault.withdraw(usdc, 1000e6, 0);
        vm.stopPrank();

        // console.log(usdc.balanceOf(address(1))); // 1998.691931
        assertEq(record.getUserAvailableTickets(address(1)), 720);
        assertEq(record.getUserTotalSeats(address(1)), 0);

        address[] memory users = new address[](1);
        users[0] = address(1);
        hoax(owner);
        record.placeSeat{value: 0.1 ether}(users);

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 720);
    }

    function testWithdrawByHelper() public {
        // deposit
        testDepositByHelper();
        vm.roll(block.number + 1);
        // withdraw
        hoax(helper);
        vault.withdrawByHelper(usdc, 10000e6, 0, address(this));
        // assertion check
        assertGt(usdc.balanceOf(helper), 9990e6); // 9990 not 10000 due to slippage
        assertEq(vault.getUserDepositBalance(address(this)), 0);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function testHarvest() public {
        deal(address(usdc), address(this), 100000e6);
        usdc.approve(address(vault), type(uint).max);
        vault.deposit(usdc, 100000e6, 0);

        skip(864000);
        uint wethBef = weth.balanceOf(treasury);
        // vault.getPoolPendingReward(); // only can test with view
        vm.recordLogs();
        vault.harvest();

        assertEq(crv.balanceOf(address(vault)), 0);
        assertEq(op.balanceOf(address(vault)), 0);
        assertGt(weth.balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);
        assertGt(weth.balanceOf(treasury), wethBef);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (uint crvAmt, uint opAmt, uint wethAmt, uint fee) = abi.decode(entries[13].data, (uint, uint, uint, uint));
        // console.log(crvAmt); // 39471738946279452263
        // console.log(opAmt); // 35611387480280085704
        // console.log(wethAmt); // 48835593914989837
        // console.log(fee); // 5426177101665537
        assertGt(crvAmt, 0);
        assertGt(opAmt, 0);
        assertGt(wethAmt, 0);
        assertGt(fee, 0);
    }

    function testUnwrapAndBridge() public {
        deal(address(weth), address(vault), 1 ether);
        hoax(owner);
        vault.unwrapAndBridge{value: 0.05 ether}();

        assertEq(weth.balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);
    }

    function testGlobalVariable() public {
        // vault
        assertEq(vault.admin(), owner);
        assertEq(address(vault.record()), address(record));
        assertEq(vault.reward(), reward);
        assertEq(vault.treasury(), treasury);
        assertEq(vault.yieldFeePerc(), 1000);
        assertEq(vault.helper(), helper);

        // record
        assertEq(record.admin(), owner);
        assertEq(record.vault(), address(vault));
        assertEq(record.dao(), address(dao));
        assertEq(record.getSeatsLength(), 0);
        // assertEq(record.getTotalSeats(), 0);
        assertEq(record.drawInProgress(), false);
    }

    function testSetter() public {
        startHoax(owner);
        // vault
        vault.setAdmin(address(1));
        assertEq(vault.admin(), address(1));
        vault.setTreasury(address(1));
        assertEq(vault.treasury(), address(1));
        vault.setReward(address(1));
        assertEq(vault.reward(), address(1));
        vault.setYieldFeePerc(2000);
        assertEq(vault.yieldFeePerc(), 2000);
        vault.setHelper(address(1));
        assertEq(vault.helper(), address(1));

        // reward
        record.setVault(address(1));
        assertEq(record.vault(), address(1));
        record.setDao(address(1));
        assertEq(record.dao(), address(1));
        record.setAdmin(address(1));
        assertEq(record.admin(), address(1));
    }

    function testAuthorization() public {
        // vault
        assertEq(vault.owner(), owner);
        vm.startPrank(owner);
        vault.setAdmin(address(1));
        vault.transferOwnership(address(1));
        vm.stopPrank();

        vm.expectRevert("only admin or owner");
        vault.unwrapAndBridge();
        vm.expectRevert("helper only");
        vault.depositByHelper(weth, 1 ether, 0, address(this));
        vm.expectRevert("helper only");
        vault.withdrawByHelper(weth, 1 ether, 0, address(this));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        vault.unPauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setAdmin(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setTreasury(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setReward(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setYieldFeePerc(0);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setHelper(address(0));

        // record
        assertEq(record.owner(), owner);
        vm.startPrank(owner);
        record.setAdmin(address(1));
        record.transferOwnership(address(1));
        vm.stopPrank();
        vm.expectRevert("only vault");
        record.updateUser(true, address(1), 0, 0);
        vm.expectRevert("only authorized");
        record.placeSeat(new address[](1));
        vm.expectRevert("only authorized");
        record.setWinnerAndRestartRound(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        record.setVault(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        record.setDao(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        record.setAdmin(address(0));
    }

    receive() external payable {}
}

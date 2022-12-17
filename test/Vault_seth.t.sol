// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "forge-std/Test.sol";
import "../src/Vault_seth.sol";
import "../src/Record_eth.sol";
import "../src/PbProxy.sol";

contract Vault_sethTest is Test {
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable weth = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IPool pool = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    address reward = 0xB7957FE76c2fEAe66B57CF3191aFD26d99EC5599;
    address dao = 0x0C9133Fa96d72C2030D63B6B35c3738D6329A313;
    address treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
    Vault_seth vault;
    Record_eth record;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address helper = 0xCf91CDBB4691a4b912928A00f809f356c0ef30D6;

    function setUp() public {
        // record = new Record_eth();
        // PbProxy proxy = new PbProxy(
        //     address(record),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // record = Record_eth(address(proxy));
        record = Record_eth(0xC530677144A7EA5BaE6Fbab0770358522b4e7071);
        Record recordImpl = new Record_eth();
        hoax(owner);
        record.upgradeTo(address(recordImpl));

        // vault = new Vault_seth();
        // proxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(record)
        //     )
        // );
        // vault = Vault_seth(payable(address(proxy)));
        vault = Vault_seth(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
        Vault_seth vaultImpl = new Vault_seth();
        hoax(owner);
        vault.upgradeTo(address(vaultImpl));

        // hoax(owner);
        // record.setVault(address(vault));
        // record.setDao(dao);
        // vault.setReward(reward);
        // vault.setHelper(helper);
    }

    // function test() public {
    //     vault.deposit{value: 1 ether}(weth, 1 ether, 0);
    //     console.log(vault.getUserBalanceInUSD(address(this))); // 1322.002050
    //     console.log(vault.getAllPoolInUSD()); // 1322.002050
    // }

    function testDepositPlaceSeat2Account() public {
        hoax(address(1));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(3600);

        hoax(address(2));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(3600);

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
        assertEq(depositBal, 1 ether);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        (depositBal,, ticketBal, lastUpdateTimestamp) = record.userInfo(address(2));
        assertEq(depositBal, 1 ether);
        assertEq(ticketBal, 0);
        assertGt(lastUpdateTimestamp, 0);

        assertEq(record.getUserTotalSeats(address(1)), 0);
        // record.getUserAvailableTickets(address(1));
        assertEq(record.getUserAvailableTickets(address(1)), 20);
        assertEq(record.getUserTotalSeats(address(2)), 0);
        assertEq(record.getUserAvailableTickets(address(2)), 10);
    }

    function testDeposit2TimesPlaceSeat() public {
        hoax(address(1));        
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(3600);
        hoax(address(1));        
        vault.deposit{value: 0.5 ether}(weth, 0.5 ether, 0);
        skip(3600);

        (uint depositBal,, uint ticketBal, uint lastUpdateTimestamp) = record.userInfo(address(1));
        assertEq(depositBal, 1.5 ether);
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
        hoax(address(1));
        vault.deposit{value: 0.5 ether}(weth, 0.5 ether, 0);
        skip(3600);

        hoax(address(2));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(3600);

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
        startHoax(address(1));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);

        assertEq(record.getUserAvailableTickets(address(1)), 1200 + 960 + 720 + 480 + 240);
        (uint depositBal,, uint ticketBal,) = record.userInfo(address(1));
        assertEq(depositBal, 5 ether);
        assertEq(ticketBal, 2400);
    }

    function testDepositPlaceSeat5Times() public {
        startHoax(address(1));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        // vault.placeSeat();
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        // vault.placeSeat(); // (240*2) + (240*1) - 240 = 480
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        // vault.placeSeat(); // (240*4) + (240*3) + (240*2) + (240*1) - 240 - 480 = 1680
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);

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
        hoax(address(1));
        vault.deposit{value: 0.5 ether}(weth, 0.5 ether, 0);
        skip(86400);

        hoax(address(2));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);

        address[] memory users = new address[](2);
        users[0] = address(1);
        users[1] = address(2);
        hoax(owner);
        record.placeSeat{value: 0.05 ether}(users);

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
        record.setWinnerAndRestartRound{value: 0.05 ether}(address(1));

        assertEq(record.getSeatsLength(), 0);
        assertEq(record.getUserTotalSeats(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(2)), 0);

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
        startHoax(address(1));
        vault.deposit{value: 0.5 ether}(weth, 0.5 ether, 0);
        skip(1800);
        vault.deposit{value: 0.5 ether}(weth, 0.5 ether, 0);

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 0);

        skip(1800);
        vm.roll(block.number + 1);
        vault.withdraw(weth, 0.95 ether, 0);
        skip(1800);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(1800);
        vm.roll(block.number + 1);
        vault.withdraw(weth, 0.91 ether, 0);

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 0);
    }

    function testDepositBalLessThan100WhenDraw() public {
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(3600);
        vm.roll(block.number + 1);
        vault.withdraw(weth, 0.95 ether, 0);

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

    function testDepositByHelper() public {
        // deposit, assume helper contract has 10 ether
        startHoax(helper, 10 ether);
        vault.depositByHelper{value: 10 ether}(weth, 10 ether, 0, address(this));
        vm.stopPrank();
        // assertion check
        assertEq(vault.getUserDepositBalance(address(this)), 10 ether);
        assertEq(address(vault).balance, 0);
    }

    function testDepositAndWithdraw() public {
        vm.expectRevert("weth only");
        vault.deposit(crv, 0, 0);
        vm.expectRevert("min 0.1 ether");
        vault.deposit(weth, 0, 0);
        vm.expectRevert("amount != msg.value");
        vault.deposit(weth, 1 ether, 0);

        // deposit
        uint[2] memory amounts = [1 ether, uint(0)];
        uint amountOut = pool.calc_token_amount(amounts, true);
        vault.deposit{value: 1 ether}(weth, 1 ether, amountOut * 99 / 100);

        // assertion check
        assertEq(address(vault).balance, 0);
        assertEq(lpToken.balanceOf(address(vault)), 0);
        // vault.getAllPoolInUSD();
        assertGt(vault.getAllPoolInUSD(), 0);
        assertGt(vault.getUserBalance(address(this)), 0);
        assertGt(vault.getUserBalanceInUSD(address(this)), 0);
        assertEq(vault.getUserDepositBalance(address(this)), 1 ether);

        vm.expectRevert("weth only");
        vault.withdraw(crv, 0, 0);
        vm.expectRevert("amount > depositBal");
        vault.withdraw(weth, 10 ether, 0);
        vm.expectRevert("same block deposit withdraw");
        vault.withdraw(weth, 1 ether, 0);

        vm.roll(block.number + 1);

        // withdraw
        // uint balBef = address(this).balance;
        uint withdrawPerc = 1 ether * 1e18 / vault.getUserDepositBalance(address(this));
        uint lpTokenAmt = vault.getUserBalance(address(this)) * withdrawPerc / 1e18;
        amountOut = pool.calc_withdraw_one_coin(lpTokenAmt, 0);
        vault.withdraw(weth, 1 ether, amountOut * 99 / 100);
        // console.log(address(this).balance - balBef); // 0.999744100548807806

        // assertion check
        assertEq(address(vault).balance, 0);
        assertEq(lpToken.balanceOf(address(vault)), 0);
        // assertEq(vault.getAllPoolInUSD(), 0);
        assertEq(vault.getUserBalance(address(this)), 0);
        assertEq(vault.getUserBalanceInUSD(address(this)), 0);
        assertEq(vault.getUserDepositBalance(address(this)), 0);
    }

    function testWithdrawAll() public {
        startHoax(address(1));
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);
        vault.deposit{value: 1 ether}(weth, 1 ether, 0);
        skip(86400);

        vm.roll(block.number + 1);
        vault.withdraw(weth, 1 ether, 0);
        vm.stopPrank();

        assertEq(record.getUserAvailableTickets(address(1)), 720);
        assertEq(record.getUserTotalSeats(address(1)), 0);

        address[] memory users = new address[](1);
        users[0] = address(1);
        hoax(owner);
        record.placeSeat{value: 0.05 ether}(users);

        assertEq(record.getUserAvailableTickets(address(1)), 0);
        assertEq(record.getUserTotalSeats(address(1)), 720);
    }

    function testWithdrawByHelper() public {
        // deposit
        testDepositByHelper();
        vm.roll(block.number + 1);
        // withdraw
        hoax(helper, 0);
        vault.withdrawByHelper(weth, 10 ether, 0, address(this));
        // assertion check
        assertGt(address(helper).balance, 9.99 ether); // 9.99 not 10 due to slippage
        assertEq(vault.getUserDepositBalance(address(this)), 0);
        assertEq(address(vault).balance, 0);
    }

    function testHarvest() public {
        vault.deposit{value: 100 ether}(weth, 100 ether, 0);

        // assume crv > 1 ether
        deal(address(crv), address(vault), 1 ether);

        skip(864000);
        uint wethBef = weth.balanceOf(treasury);
        (uint crvReward, uint opReward) = vault.getPoolPendingReward();
        assertGt(crvReward, 0);
        assertGt(opReward, 0);
        vm.recordLogs();
        vault.harvest();

        assertEq(crv.balanceOf(address(vault)), 0);
        assertEq(op.balanceOf(address(vault)), 0);
        assertGt(weth.balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);
        assertGt(weth.balanceOf(treasury), wethBef);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (uint crvAmt, uint opAmt, uint wethAmt, uint fee) = abi.decode(entries[13].data, (uint, uint, uint, uint));
        // console.log(crvAmt); // 1.447906871113135621
        // console.log(opAmt); // 4.806133369597622030
        // console.log(wethAmt); // 0.003586428305155558
        // console.log(fee); // 0.000398492033906173
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
        address[] memory users = new address[](1);
        users[0] = address(this);
        assertEq(record.getTotalSeats(users), 0);
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

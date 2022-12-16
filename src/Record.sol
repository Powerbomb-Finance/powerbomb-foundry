// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ILayerZeroEndpoint.sol";

/// @title contract to record user balance, ticket, and place seat
/// @author siew
contract Record is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    ILayerZeroEndpoint constant LZ_ENDPOINT = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

    struct User {
        uint depositBal; // deposit balance without slippage, for calculate ticket
        uint lpTokenBal; // lpToken amount owned after deposit into farm
        uint ticketBal; // ticket balance after user deposit/withdraw or admin place seat
        uint lastUpdateTimestamp; // timestamp when update ticket balance
    }
    mapping(address => User) public userInfo;

    struct Seat {
        address user; // user address
        uint from; // user seat number start
        uint to; // user seat number end
    }
    Seat[] public seats;

    address public vault;
    address public dao; // on ethereum
    address public admin;
    uint public totalSeatsAfterPlaceSeat;
    bool public drawInProgress;

    event UpdateTicketAmount(address indexed user, uint depositHour, uint depositInHundred);
    event DrawInProgress(bool inProgress);
    event PlaceSeat(address indexed user, uint from, uint to, uint seatIndex);
    event SetWinnerAndRestartRound(address winner);
    event SetVault(address vault_);
    event SetDao(address dao_);
    event SetAdmin(address admin);

    modifier onlyVault {
        require(msg.sender == address(vault), "only vault");
        _;
    }

    modifier onlyAuthorized {
        require(msg.sender == admin || msg.sender == owner(), "only authorized");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();

        admin = msg.sender;
    }

    /// @notice update user deposit/withdraw/ticket, only callable by vault
    /// @param isDeposit is deposit?
    /// @param account user address
    /// @param amount actual amount deposit
    /// @param lpTokenAmt lp token amount deposit
    function updateUser(bool isDeposit, address account, uint amount, uint lpTokenAmt) external onlyVault {
        User storage user = userInfo[account];

        if (isDeposit) {
            if (user.lastUpdateTimestamp == 0) {
                // user's first record
                user.lastUpdateTimestamp = block.timestamp;
            } else {
                _updateTicketAmount(account);
            }
            // _updateTicketAmount() use user.depositBal to calculate ticket
            // so add deposit amount must after _updateTicketAmount()
            user.depositBal += amount;
            user.lpTokenBal += lpTokenAmt;

        } else { // withdraw
            _updateTicketAmount(account);
            // _updateTicketAmount() use user.depositBal to calculate ticket
            // so subtract withdraw amount must after _updateTicketAmount()
            user.depositBal -= amount;
            user.lpTokenBal -= lpTokenAmt;
        }
    }

    /// @notice update user ticket amount
    /// @param user_ user address
    function _updateTicketAmount(address user_) internal virtual {
        User storage user = userInfo[user_];
        // it is okay to use block.timestamp to calculate depositHour
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        if (depositHour > 0 && depositInHundred > 0) {
            // explicitly performs multiplication on the result of a division
            // because ticket determine by minimum 1 depositHour and minimum 100e6 depositInHundred
            user.ticketBal += depositHour * depositInHundred; // 1 deposit hour * $100 = 1 ticket
            emit UpdateTicketAmount(user_, depositHour, depositInHundred);
        }
        // update timestamp after calculate ticket from last timestamp
        user.lastUpdateTimestamp = block.timestamp;
    }

    /// @notice place seat for all depositors and send total seats to ethereum dao contract
    /// @notice only callable by admin or owner
    /// @dev only call this function when ready to draw
    /// @param users user address list
    function placeSeat(address[] calldata users) external payable onlyAuthorized {
        require(!drawInProgress, "draw in progress");

        uint totalSeats = 0;
        for (uint i = 0; i < users.length; i++) {
            // call _placeSeat() for each user and add up total seats
            totalSeats += _placeSeat(users[i], totalSeats);
        }

        totalSeatsAfterPlaceSeat = totalSeats;
        drawInProgress = true;
        emit DrawInProgress(true);

        // send total seats to ethereum dao contract through layer zero
        LZ_ENDPOINT.send{value: msg.value}(
            101, // _dstChainId, 101 is ethereum
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(totalSeats, address(0)), // _payload, (total seats, winner)
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            abi.encodePacked(uint16(1), uint(40000)) // _adapterParams, 1 = version, 40000 = gas limit on dstChain
        );
    }

    /// @notice place seat for all depositors
    /// @param user user address
    /// @param totalSeats total seats
    /// for example total seats = 10, user tickets  = 5
    /// user seats start from 10, end by 14
    /// new total seats = 10 + 5 = 15
    /// then next user seats start form 15
    /// @return totalSeats accumulate total seats
    function _placeSeat(address user, uint totalSeats) internal virtual returns (uint) {
        // update user ticket amount before place seat
        _updateTicketAmount(user);

        // even if ticket > 0, if user depositBal is lower than 99 USD,
        // user are not eligible in this round, and user ticketBal will reset to 0
        if (userInfo[user].depositBal > 99e6) {
            uint ticket = userInfo[user].ticketBal;
            if (ticket > 0) {
                // refer @param totalSeats above
                uint from = totalSeats;
                uint to = from + ticket - 1;

                // push seats to seats list and wait for random seat draw
                seats.push(Seat({
                    user: user,
                    from: from,
                    to: to
                }));

                // reset user ticket balance
                userInfo[user].ticketBal = 0;
                // sum up total seats
                totalSeats += ticket;

                emit PlaceSeat(user, from, to, seats.length - 1);
            }

        } else {
            userInfo[user].ticketBal = 0;
        }

        return totalSeats;
    }

    /// @notice set winnerand send winner to ethereum dao contract
    /// @notice only callable by admin or owner
    /// @notice this function won't affect user accumulate tickets after placeSeat() 
    function setWinnerAndRestartRound(address winner) external payable onlyAuthorized {
        require(winner != address(0), "winner is zero address");

        // delete all seats that been places in placeSeat()
        delete seats;
        totalSeatsAfterPlaceSeat = 0;
        drawInProgress = false;
        emit DrawInProgress(false);

        // send winner to ethereum dao contract through layer zero
        LZ_ENDPOINT.send{value: msg.value}(
            101, // _dstChainId, 101 is ethereum
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(0, winner), // _payload, (total seats, winner)
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            abi.encodePacked(uint16(1), uint(40000)) // _adapterParams, 1 = version, 40000 = gas limit on dstChain
        );

        emit SetWinnerAndRestartRound(winner);
    }

    /// @notice set new vault, only callable by owner
    /// @param vault_ new vault contract address
    function setVault(address vault_) external onlyOwner {
        require(vault_ != address(0), "0 address");
        vault = vault_;

        emit SetVault(vault_);
    }

    /// @notice set new dao, only callable by owner
    /// @param dao_ new dao contract address
    function setDao(address dao_) external onlyOwner {
        require(dao_ != address(0), "0 address");
        dao = dao_;

        emit SetDao(dao_);
    }

    /// @notice set new admin, only callable by owner
    /// @param admin_ new admin address
    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "0 address");
        admin = admin_;

        emit SetAdmin(admin_);
    }

    /// @notice get user ticket that had been place seat
    /// @dev this function is valid only after placeSeat() been called
    function getUserTotalSeats(address user_) public view returns (uint ticket) {
        for (uint i = 0; i < seats.length; i++) {
            // loop through all seats and sum up user tickets
            Seat memory seat = seats[i];
            if (seat.user == user_) {
                // seat.to and seat.from are inclusive
                // example seat from 10 to 14,
                // ticket = 14 - 10 + 1 = 5
                ticket += seat.to - seat.from + 1;
            }
        }
    }

    /// @notice get user available ticket to claim (not yet record into user.ticketBal) +
    /// user pending ticket (record into user.ticketBal but not yet place seat)
    /// @param user_ user address to query
    /// @return ticket user available ticket
    function getUserAvailableTickets(address user_) public virtual view returns (uint ticket) {
        User memory user = userInfo[user_];

        // get user available ticket to claim (not yet record into user.ticketBal)
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        // explicitly performs multiplication on the result of a division
        // because ticket determine by minimum 1 depositHour and minimum 100e6 depositInHundred
        uint availableTicket = depositHour * depositInHundred;

        // get user pending ticket (record into user.ticketBal but not yet place seat)
        uint pendingTicket = user.ticketBal;

        return availableTicket + pendingTicket;
    }

    /// @notice get user total tickets
    /// @param user_ user address
    /// @return totalTickets user total tickets
    function getUserTotalTickets(address user_) external view returns (uint) {
        uint ticketBeenPlaceSeat = getUserTotalSeats(user_);
        uint pendingAndAvailableTicket = getUserAvailableTickets(user_);

        return ticketBeenPlaceSeat + pendingAndAvailableTicket;
    }

    /// @notice get estimated total tickets that haven't actual place seat
    /// @notice actual total seats when place seat might be different
    function getTotalSeats(address[] calldata users) external view returns (uint totalTickets) {
        for (uint i = 0; i < users.length; i++) {
            totalTickets += getUserAvailableTickets(users[i]);
        }
    }

    /// @notice get length of seats list
    /// @return length of seats list
    function getSeatsLength() external view returns (uint) {
        return seats.length;
    }

    /// @notice query the owner of the seat number
    /// @notice this is usually used when get random seat number from chainlink,
    /// and query the owner of the seat number as winner
    /// @param seatNum seat number
    /// @return owner owner address
    function getSeatOwner(uint seatNum) external view returns (address owner) {
        Seat[] memory _seats = seats;
        for (uint i = 0; i < _seats.length; i++) {
            // loop through all seats list
            Seat memory seat = _seats[i];
            if (seatNum >= seat.from && seatNum <= seat.to) {
                // query the seat by match if seat number is higher than seat.from or lower than seat.to
                // in each seat in seat list
                owner = seat.user;
                // return the owner address and break the loop
                break;
            }
        }
    }

    /// @dev for uups upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
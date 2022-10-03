// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ILayerZeroEndpoint.sol";

contract Record is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    ILayerZeroEndpoint constant lzEndpoint = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

    struct User {
        uint depositBal; // deposit balance without slippage, for calculate ticket
        uint lpTokenBal; // lpToken amount owned after deposit into farm
        uint ticketBal;
        uint lastUpdateTimestamp;
    }
    mapping(address => User) public userInfo;

    struct Seat {
        address user;
        uint from;
        uint to;
    }
    Seat[] public seats;

    address public vault;
    address public dao; // on ethereum
    address public admin;
    uint public lastSeat;
    bool public drawInProgress;

    event UpdateTicketAmount(address indexed user, uint depositHour, uint depositInHundred);
    event DrawInProgress(bool inProgress);
    event PlaceSeat(address indexed user, uint from, uint to, uint seatIndex);
    event SetWinnerAndRestartRound(address winner);
    event SetVault(address _vault);
    event SetDao(address _dao);
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

    function updateUser(bool deposit, address account, uint amount, uint lpTokenAmt) external onlyVault {
        User storage user = userInfo[account];

        if (deposit) {
            if (user.lastUpdateTimestamp == 0) { // first record
                user.lastUpdateTimestamp = block.timestamp;
            } else {
                _updateTicketAmount(account);
            }
            user.depositBal += amount; // must after update ticket
            user.lpTokenBal += lpTokenAmt;

        } else { // withdraw
            _updateTicketAmount(account);
            user.lpTokenBal -= lpTokenAmt;
            user.depositBal -= amount;
        }
    }

    // function updateTicketAmount() external {
    //     _updateTicketAmount(msg.sender);
    // }

    function _updateTicketAmount(address _user) private {
        User storage user = userInfo[_user];
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        if (depositHour > 0 && depositInHundred > 0) {
            user.ticketBal += depositHour * depositInHundred; // 1 deposit hour * $100 = 1 ticket
            emit UpdateTicketAmount(_user, depositHour, depositInHundred);
        }
        user.lastUpdateTimestamp = block.timestamp;
    }

    ///@notice only call this function when ready to draw
    function placeSeat(address[] calldata users) external payable onlyAuthorized {

        for (uint i; i < users.length; i++) {
            _placeSeat(users[i]);
        }

        drawInProgress = true;
        emit DrawInProgress(true);

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(lastSeat, address(0)), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            bytes("") // _adapterParams
        );
    }

    function _placeSeat(address user) private {
        _updateTicketAmount(user);

        if (userInfo[user].depositBal > 99e6) {
            uint ticket = userInfo[user].ticketBal;
            if (ticket > 0) {
                uint from = lastSeat;
                uint to = from + ticket - 1;

                seats.push(Seat({
                    user: user,
                    from: from,
                    to: to
                }));

                userInfo[user].ticketBal = 0;
                lastSeat += ticket;

                emit PlaceSeat(user, from, to, seats.length - 1);
            }

        } else {
            userInfo[user].ticketBal = 0;
        }
    }

    function setWinnerAndRestartRound(address winner) external payable onlyAuthorized {
        require(winner != address(0), "winner is zero address");

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(0, winner), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            bytes("") // _adapterParams
        );

        delete seats;
        drawInProgress = false;
        lastSeat = 0;

        emit SetWinnerAndRestartRound(winner);
        emit DrawInProgress(false);
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;

        emit SetVault(_vault);
    }

    function setDao(address _dao) external onlyOwner {
        dao = _dao;

        emit SetDao(_dao);
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    ///@notice get user ticket that had been place seat
    ///@dev this function is valid only if placeSeat() is called in latest implementation
    function getUserTotalSeats(address _user) public view returns (uint ticket) {
        for (uint i; i < seats.length; i++) {
            Seat memory seat = seats[i];
            if (seat.user == _user) {
                ticket += seat.to - seat.from + 1; // because seat start with 0
            }
        }
    }

    ///@notice get user pending ticket (not yet place seat) and user available ticket to claim
    function getUserAvailableTickets(address _user) public view returns (uint ticket) {
        // get user pending ticket (not yet place seat)
        User memory user = userInfo[_user];
        uint pendingTicket = user.ticketBal;

        // get user available ticket to claim
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        uint availableTicket = depositHour * depositInHundred;

        return pendingTicket + availableTicket;
    }

    function getUserTotalTickets(address _user) external view returns (uint) {
        uint ticketBeenPlaceSeat = getUserTotalSeats(_user);
        uint pendingAndAvailableTicket = getUserAvailableTickets(_user);

        return ticketBeenPlaceSeat + pendingAndAvailableTicket;
    }

    ///@notice this return users available tickets that haven't actual place seat
    ///@notice actual total seats when place seat might be different
    function getTotalSeats(address[] calldata users) external view returns (uint totalSeats) {
        for (uint i; i < users.length; i++) {
            totalSeats += getUserAvailableTickets(users[i]);
        }
    }

    function getSeatsLength() external view returns (uint) {
        return seats.length;
    }

    function getSeatOwner(uint seatNum) external view returns (address owner) {
        Seat[] memory _seats = seats;
        for (uint i; i < _seats.length; i++) {
            Seat memory seat = _seats[i];
            if (seatNum >= seat.from && seatNum <= seat.to) {
                owner = seat.user;
                break;
            }
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
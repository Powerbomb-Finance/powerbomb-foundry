// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

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
    uint public lastSeat; // unused variable
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

    function _updateTicketAmount(address _user) internal virtual {
        User storage user = userInfo[_user];
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        if (depositHour > 0 && depositInHundred > 0) {
            // explicitly performs multiplication on the result of a division
            // because ticket determine by minimum 1 depositHour and minimum 100e6 depositInHundred
            user.ticketBal += depositHour * depositInHundred; // 1 deposit hour * $100 = 1 ticket
            emit UpdateTicketAmount(_user, depositHour, depositInHundred);
        }
        user.lastUpdateTimestamp = block.timestamp;
    }

    ///@notice only call this function when ready to draw
    function placeSeat(address[] calldata users) external payable onlyAuthorized {

        uint _lastSeat;
        for (uint i = 0; i < users.length; i++) {
            _lastSeat += _placeSeat(users[i], _lastSeat);
        }

        drawInProgress = true;
        emit DrawInProgress(true);

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(_lastSeat, address(0)), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            abi.encodePacked(uint16(1), uint(40000)) // _adapterParams, 1 = version, 40000 = gas limit on dstChain
        );
    }

    function _placeSeat(address user, uint _lastSeat) internal virtual returns (uint) {
        _updateTicketAmount(user);

        if (userInfo[user].depositBal > 99e6) {
            uint ticket = userInfo[user].ticketBal;
            if (ticket > 0) {
                uint from = _lastSeat;
                uint to = from + ticket - 1;

                seats.push(Seat({
                    user: user,
                    from: from,
                    to: to
                }));

                userInfo[user].ticketBal = 0;
                _lastSeat += ticket;

                emit PlaceSeat(user, from, to, seats.length - 1);
            }

        } else {
            userInfo[user].ticketBal = 0;
        }

        return _lastSeat;
    }

    function setWinnerAndRestartRound(address winner) external payable onlyAuthorized {
        require(winner != address(0), "winner is zero address");

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(dao, address(this)), // _path
            abi.encode(0, winner), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            abi.encodePacked(uint16(1), uint(40000)) // _adapterParams, 1 = version, 40000 = gas limit on dstChain
        );

        delete seats;
        drawInProgress = false;

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
    ///@dev this function is valid only after placeSeat() been called in latest implementation
    function getUserTotalSeats(address _user) public view returns (uint ticket) {
        for (uint i = 0; i < seats.length; i++) {
            Seat memory seat = seats[i];
            if (seat.user == _user) {
                ticket += seat.to - seat.from + 1; // because seat start with 0
            }
        }
    }

    ///@notice get user pending ticket (not yet place seat) and user available ticket to claim
    function getUserAvailableTickets(address _user) public virtual view returns (uint ticket) {
        // get user pending ticket (not yet place seat)
        User memory user = userInfo[_user];
        uint pendingTicket = user.ticketBal;

        // get user available ticket to claim
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInHundred = user.depositBal / 100e6;
        // explicitly performs multiplication on the result of a division
        // because ticket determine by minimum 1 depositHour and minimum 100e6 depositInHundred
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
        for (uint i = 0; i < users.length; i++) {
            totalSeats += getUserAvailableTickets(users[i]);
        }
    }

    function getSeatsLength() external view returns (uint) {
        return seats.length;
    }

    function getSeatOwner(uint seatNum) external view returns (address owner) {
        Seat[] memory _seats = seats;
        for (uint i = 0; i < _seats.length; i++) {
            Seat memory seat = _seats[i];
            if (seatNum >= seat.from && seatNum <= seat.to) {
                owner = seat.user;
                break;
            }
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
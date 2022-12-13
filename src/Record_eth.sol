// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Record.sol";

contract Record_eth is Record {

    function _updateTicketAmount(address _user) internal override {
        User storage user = userInfo[_user];
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInZeroPointOneEther = user.depositBal / 0.1 ether;
        if (depositHour > 0 && depositInZeroPointOneEther > 0) {
            user.ticketBal += depositHour * depositInZeroPointOneEther; // 1 deposit hour * 0.1 ether = 1 ticket
            emit UpdateTicketAmount(_user, depositHour, depositInZeroPointOneEther);
        }
        user.lastUpdateTimestamp = block.timestamp;
    }

    function _placeSeat(address user, uint _lastSeat) internal override returns (uint) {
        _updateTicketAmount(user);

        if (userInfo[user].depositBal > 0.1 ether) {
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

    function getUserAvailableTickets(address _user) public override view returns (uint ticket) {
        // get user pending ticket (not yet place seat)
        User memory user = userInfo[_user];
        uint pendingTicket = user.ticketBal;

        // get user available ticket to claim
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInZeroPointOneEther = user.depositBal / 0.1 ether;
        uint availableTicket = depositHour * depositInZeroPointOneEther;

        return pendingTicket + availableTicket;
    }
}
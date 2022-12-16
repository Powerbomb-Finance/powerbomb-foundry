// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./Record.sol";

contract Record_eth is Record {

    /// @inheritdoc Record
    function _updateTicketAmount(address user_) internal override {
        User storage user = userInfo[user_];
        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInZeroPointOneEther = user.depositBal / 0.1 ether;
        if (depositHour > 0 && depositInZeroPointOneEther > 0) {
            user.ticketBal += depositHour * depositInZeroPointOneEther; // 1 deposit hour * 0.1 ether = 1 ticket
            emit UpdateTicketAmount(user_, depositHour, depositInZeroPointOneEther);
        }
        user.lastUpdateTimestamp = block.timestamp;
    }

    /// @inheritdoc Record
    function _placeSeat(address user, uint totalSeats) internal override returns (uint) {
        _updateTicketAmount(user);

        if (userInfo[user].depositBal > 0.1 ether) {
            uint ticket = userInfo[user].ticketBal;
            if (ticket > 0) {
                uint from = totalSeats;
                uint to = from + ticket - 1;

                seats.push(Seat({
                    user: user,
                    from: from,
                    to: to
                }));

                userInfo[user].ticketBal = 0;
                totalSeats += ticket;

                emit PlaceSeat(user, from, to, seats.length - 1);
            }

        } else {
            userInfo[user].ticketBal = 0;
        }

        return totalSeats;
    }

    /// @inheritdoc Record
    function getUserAvailableTickets(address user_) public override view returns (uint ticket) {
        User memory user = userInfo[user_];

        uint depositHour = (block.timestamp - user.lastUpdateTimestamp) / 3600;
        uint depositInZeroPointOneEther = user.depositBal / 0.1 ether;
        uint availableTicket = depositHour * depositInZeroPointOneEther;

        uint pendingTicket = user.ticketBal;

        return availableTicket + pendingTicket;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "interface/IFarm.sol";
import "interface/ILayerZeroEndpoint.sol";

contract PengTogether is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {

    IERC20Upgradeable constant usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    ILayerZeroEndpoint constant lzEndpoint = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

    struct User {
        uint depositBal; // deposit balance without slippage, for calculate ticket
        uint lpTokenBal; // lpToken amount owned after deposit into farm
        uint ticketBal;
        uint lastUpdateTimestamp;
    }
    mapping(address => User) public userInfo;
    mapping(address => uint) internal depositedBlock;

    struct Seat {
        address user;
        uint from;
        uint to;
    }
    Seat[] public seats;

    uint private lastSeat;
    bool public luckyDrawInProgress;
    address public admin;
    IFarm public farm;

    event Deposit(address indexed user, uint amount, uint lpTokenAmt);
    event Withdraw(address indexed user, uint amount, uint lpTokenAmt, uint actualAmt);
    event UpdateTicketAmount(address indexed user, uint depositHour, uint depositInHundred);
    event LuckyDrawInProgress(bool inProgress);
    event PlaceSeat(address indexed user, uint from, uint to, uint seatIndex);
    event SetWinnerAndRestartRound(address winner);
    event SetFarm(address farm);
    event SetAdmin(address admin);

    modifier onlyAuthorized {
        require(msg.sender == admin || msg.sender == owner(), "only authorized");
        _;
    }

    function initialize(IFarm _farm) external initializer {
        __Ownable_init();

        admin = msg.sender;
        farm = _farm;

        usdc.approve(address(farm), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external nonReentrant whenNotPaused {
        require(token == usdc, "usdc only");
        require(amount >= 100e6, "min $100");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint lpTokenAmt = farm.deposit(amount, amountOutMin);

        User storage user = userInfo[msg.sender];
        if (user.lastUpdateTimestamp == 0) { // first record
            user.lastUpdateTimestamp = block.timestamp;
        } else {
            _updateTicketAmount(msg.sender);
        }
        user.depositBal += amount; // must after update ticket
        user.lpTokenBal += lpTokenAmt;
        depositedBlock[msg.sender] = block.number;

        emit Deposit(msg.sender, amount, lpTokenAmt);
    }

    function withdraw(IERC20Upgradeable token, uint amount, uint amountOutMin) external nonReentrant {
        require(token == usdc, "usdc only");
        User storage user = userInfo[msg.sender];
        require(user.depositBal >= amount, "amount > depositBal");
        require(depositedBlock[msg.sender] != block.number, "same block deposit withdraw");

        // moved to after user.depositBal -= amount to calculate tickets
        // based on user.depositBal after withdrawal
        _updateTicketAmount(msg.sender);

        uint withdrawPerc = amount * 1e18 / user.depositBal;
        uint lpTokenAmt = user.lpTokenBal * withdrawPerc / 1e18;
        uint actualAmt = farm.withdraw(lpTokenAmt, amountOutMin);

        user.lpTokenBal -= lpTokenAmt;
        user.depositBal -= amount;

        // _updateTicketAmount(msg.sender);

        usdc.transfer(msg.sender, actualAmt);
        emit Withdraw(msg.sender, amount, lpTokenAmt, actualAmt);
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
            user.lastUpdateTimestamp = block.timestamp;

            emit UpdateTicketAmount(_user, depositHour, depositInHundred);
        }
    }

    function placeSeat() external nonReentrant whenNotPaused {
        require(!luckyDrawInProgress, "lucky draw in progress");
        _placeSeat(msg.sender);
    }

    ///@notice only call this function when ready to lucky draw
    function placeSeat(address[] calldata users) external payable onlyAuthorized {

        for (uint i; i < users.length; i++) {
            _placeSeat(users[i]);
        }

        luckyDrawInProgress = true;
        emit LuckyDrawInProgress(true);

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(farm.reward(), address(this)), // _path
            abi.encode(lastSeat, address(0)), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            bytes("") // _adapterParams
        );
    }

    function _placeSeat(address user) private {
        _updateTicketAmount(user);

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
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function setWinnerAndRestartRound(address winner) external payable onlyAuthorized {
        require(winner != address(0), "winner is zero address");

        lzEndpoint.send{value: msg.value}(
            101, // _dstChainId
            abi.encodePacked(farm.reward(), address(this)), // _path
            abi.encode(0, winner), // _payload
            payable(admin), // _refundAddress
            address(0), // _zroPaymentAddress
            bytes("") // _adapterParams
        );

        delete seats;
        luckyDrawInProgress = false;
        lastSeat = 0;

        emit SetWinnerAndRestartRound(winner);
        emit LuckyDrawInProgress(false);
    }

    function setFarm(IFarm _farm) external onlyOwner {
        farm = _farm;
        usdc.approve(address(farm), type(uint).max);

        emit SetFarm(address(_farm));
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    ///@notice get user ticket that had been place seat
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

    ///@notice this is excluded those who owned/availableToClaim tickets but haven't place seat if any
    function getTotalSeats() external view returns (uint) {
        return lastSeat;
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

    function getAllPoolInUSD() external view returns (uint) {
        return farm.getAllPoolInUSD(); // 6 decimals
    }

    ///@notice user deposit balance without slippage
    function getUserDepositBalance(address account) external view returns (uint) {
        return userInfo[account].depositBal;
    }

    ///@notice user lpToken balance after deposit into farm, 18 decimals
    function getUserBalance(address account) external view returns (uint) {
        return userInfo[account].lpTokenBal;
    }

    ///@notice user actual balance in usd after deposit into farm (after slippage), 6 decimals
    function getUserBalanceInUSD(address account) external view returns (uint) {
        return userInfo[account].lpTokenBal * farm.getPricePerFullShareInUSD() / 1e18;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

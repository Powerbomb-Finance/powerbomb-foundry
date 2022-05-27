// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "oz-upgradeable/proxy/utils/Initializable.sol";
import "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./lib/NonblockingLzApp.sol";
import "./interfaces/IBridge.sol";

contract PbState is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, NonblockingLzApp {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct User {
        uint balance;
        uint rewardStartAt;
    }
    // userInfo[userAddr][rewardTokenAddr]
    mapping(address => mapping(address => User)) public userInfo;

    struct Reward {
        uint accRewardPerlpToken;
        uint basePool;
    }
    // rewardInfo[rewardTokenAddr]
    mapping(address => Reward) public rewardInfo;

    address[] public rewardTokenList;
    IBridge public bridge;
    mapping(address => bool) public isAuthorized;

    event Record(address account, uint amount, address rewardToken, uint chainId, RecordType recordType);

    modifier onlyAuthorized {
        require(msg.sender == address(this) || isAuthorized[msg.sender], "Not authorized");
        _;
    }

    function initialize(IBridge _bridge) external initializer {
        bridge = _bridge;
    }

    function recordDeposit(address account, uint amount, address rewardToken, uint chainId) public onlyAuthorized {
        User storage user = userInfo[account][rewardToken];
        user.balance += amount;
        user.rewardStartAt += (amount * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool += amount;
        emit Record(account, amount, rewardToken, chainId, RecordType.DEPOSIT);
    }

    function recordWithdraw(address account, uint amount, address rewardToken, uint chainId) public onlyAuthorized {
        User storage user = userInfo[account][rewardToken];
        user.balance -= amount;
        user.rewardStartAt = (user.balance * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool -= amount;
        emit Record(account, amount, rewardToken, chainId, RecordType.WITHDRAW);
    }

    function recordClaim(address account, uint chainId) public onlyAuthorized {
        // Loop through each reward
        for (uint i = 0; i < rewardTokenList.length; i ++) {
            address _rewardToken = rewardTokenList[i];
            User storage user = userInfo[account][_rewardToken];
            if (user.balance > 0) {
                // Calculate user reward
                uint rewardTokenAmt = (user.balance * rewardInfo[_rewardToken].accRewardPerlpToken / 1e36) - user.rewardStartAt;
                if (rewardTokenAmt > 0) {
                    user.rewardStartAt += rewardTokenAmt;
                    if (chainId == block.chainid) {
                        // Call function from Avalanche PbGateway
                        IERC20Upgradeable(_rewardToken).safeTransfer(account, rewardTokenAmt);
                    } else {
                        // Repay claim by bridge token to user in corresponding chain
                        bridge.deposit(account, chainId, _rewardToken, rewardTokenAmt);
                    }
                    emit Record(account, rewardTokenAmt, _rewardToken, chainId, RecordType.CLAIM);
                }
            }
        }
    }

    // for LayerZero payload record
    enum RecordType { DEPOSIT, WITHDRAW, CLAIM }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory data) internal override {
        (
            address account,
            uint amount,
            address rewardToken,
            uint chainId,
            RecordType recordType
        ) = abi.decode(data, (address, uint, address, uint, RecordType));
        if (recordType == RecordType.DEPOSIT) {
            recordDeposit(account, amount, rewardToken, chainId);
        } else if (recordType == RecordType.WITHDRAW) {
            recordWithdraw(account, amount, rewardToken, chainId);
        } else { // RecordType.CLAIM
            recordClaim(account, chainId);
        }
    }

    function addRewardToken(address rewardToken) external onlyOwner {
        rewardTokenList.push(rewardToken);
    }

    function setRewardToken(address rewardToken, uint index) external onlyOwner {
        rewardTokenList[index] = rewardToken;
    }

    function setAuthorized(address addr) external onlyOwner {
        isAuthorized[addr] = true;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

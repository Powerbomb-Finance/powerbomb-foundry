// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IPool.sol";
import "../interface/IGauge.sol";
import "../interface/IReward.sol";
import "../interface/IChainlink.sol";

contract PbCrvTri is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant USDT = IERC20Upgradeable(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable constant crv3crypto = IERC20Upgradeable(0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2);
    IPool constant pool = IPool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    IGauge constant gauge = IGauge(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    IChainlink constant USDTPriceOracle = IChainlink(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7);

    mapping(address => uint) private depositedBlock;
    mapping(address => IReward) public rewardInfo;
    address[] public rewards;

    event Deposit(address indexed token, uint tokenAmt, uint lpTokenAmt, address indexed rewardToken);
    event Withdraw(address indexed token, uint lpTokenAmt, uint tokenAmt, address indexed rewardToken);
    event AddNewReward(address rewardContract, address rewardToken);
    event SetCurrentReward(address oldRewardContract, address newRewardContract, address rewardToken, uint index);
    event RemoveReward(address rewardToken, uint index);

    function initialize() external initializer {
        __Ownable_init();

        USDT.safeApprove(address(pool), type(uint).max);
        WBTC.safeApprove(address(pool), type(uint).max);
        WETH.safeApprove(address(pool), type(uint).max);
        crv3crypto.safeApprove(address(gauge), type(uint).max);
        crv3crypto.safeApprove(address(pool), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin, address rewardToken) external nonReentrant whenNotPaused {
        require(token == USDT || token == WBTC || token == WETH || token == crv3crypto, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint crv3cryptoAmt;
        if (token != crv3crypto) {
            uint[3] memory amounts;
            if (token == USDT) amounts[0] = amount;
            else if (token == WBTC) amounts[1] = amount;
            else amounts[2] = amount; // token == WETH
            pool.add_liquidity(amounts, amountOutMin);
            crv3cryptoAmt = crv3crypto.balanceOf(address(this));
        } else {
            crv3cryptoAmt = amount;
        }

        gauge.deposit(crv3cryptoAmt);

        IReward reward = rewardInfo[rewardToken];
        reward.recordDeposit(msg.sender, crv3cryptoAmt);
        emit Deposit(address(token), amount, crv3cryptoAmt, rewardToken);
    }

    function withdraw(IERC20Upgradeable token, uint lpTokenAmt, uint amountOutMin, address rewardToken) external nonReentrant {
        require(token == USDT || token == WBTC || token == WETH || token == crv3crypto, "Invalid token");
        IReward reward = rewardInfo[rewardToken];
        (uint balance,) = reward.userInfo(msg.sender);
        require(lpTokenAmt > 0 && balance >= lpTokenAmt, "Invalid lpTokenAmt to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        reward.recordWithdraw(msg.sender, lpTokenAmt);
        gauge.withdraw(lpTokenAmt);

        uint tokenAmt;
        if (token != crv3crypto) {
            uint i;
            if (token == USDT) i = 0;
            else if (token == WBTC) i = 1;
            else i = 2; // WETH
            pool.remove_liquidity_one_coin(lpTokenAmt, i, amountOutMin);
            tokenAmt = token.balanceOf(address(this));
        } else {
            tokenAmt = lpTokenAmt;
        }
        token.safeTransfer(msg.sender, tokenAmt);

        emit Withdraw(address(token), lpTokenAmt, tokenAmt, rewardToken);
    }

    function harvest() public {
        gauge.claim_rewards();

        uint CRVAmt = CRV.balanceOf(address(this));
        uint allPool = getAllPool();

        for (uint i; i < rewards.length; i++) {
            if (rewards[i] != address(0)) {
                IReward reward = IReward(rewards[i]);
                uint rewardPool = reward.getAllPool();
                uint poolPerc = rewardPool * 1e18 / allPool;
                uint _CRVAmt = poolPerc * CRVAmt / 1e18;
                reward.harvest(_CRVAmt);
            }
        }
    }

    function claimReward() external nonReentrant {
        // Harvest first to provide user updated reward
        harvest();
        // Claim rewardToken on all reward contracts
        for (uint i; i < rewards.length; i++) {
            if (rewards[i] != address(0)) {
                IReward(rewards[i]).claim(msg.sender);
            }
        }
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function addNewReward(address rewardContract, address rewardToken) external onlyOwner {
        require(address(rewardInfo[rewardToken]) == address(0), "Reward contract added");
        rewardInfo[rewardToken] = IReward(rewardContract);
        rewards.push(rewardContract);
        CRV.safeApprove(rewardContract, type(uint).max);
        emit AddNewReward(rewardContract, rewardToken);
    }

    function setCurrentReward(address rewardContract, address rewardToken, uint index) external onlyOwner {
        address _rewardContract = address(rewardInfo[rewardToken]);
        require(_rewardContract != address(0), "Reward contract not added");
        require(_rewardContract != rewardContract, "Same reward contract");
        require(rewards[index] == _rewardContract, "Wrong index");
        CRV.safeApprove(_rewardContract, 0);
        rewardInfo[rewardToken] = IReward(rewardContract);
        rewards[index] = rewardContract;
        CRV.safeApprove(rewardContract, type(uint).max);
        emit SetCurrentReward(_rewardContract, rewardContract, rewardToken, index);
    }

    function removeReward(address rewardToken, uint index) external onlyOwner {
        address rewardContract = rewards[index];
        IReward reward = rewardInfo[rewardToken];
        require(rewardContract == address(reward), "Wrong rewardToken or index");
        require(reward.getAllPool() == 0, "Reward pool not 0");
        CRV.safeApprove(address(rewards[index]), 0);
        rewards[index] = address(0);
        rewardInfo[rewardToken] = IReward(address(0));
        emit RemoveReward(rewardToken, index);
    }

    function getPricePerFullShareInUSD() internal view returns (uint) {
        (, int answer,,,) = USDTPriceOracle.latestRoundData();
        // Get total USD for each asset (18 decimals)
        uint totalUSDTInUSD = pool.balances(0) * uint(answer) * 1e4;
        uint totalWBTCInUSD = pool.balances(1) * pool.price_oracle(0) / 1e8;
        uint totalWETHInUSD = pool.balances(2) * pool.price_oracle(1) / 1e18;
        uint totalAssetsInUSD = totalUSDTInUSD + totalWBTCInUSD + totalWETHInUSD;
        // Calculate price per full share
        return totalAssetsInUSD * 1e6 / crv3crypto.totalSupply(); // 6 decimals
    }

    function getAllPool() public view returns (uint) {
        return gauge.balanceOf(address(this)); // lpToken, 18 decimals
    }

    function getAllPoolInUSD() external view returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    /// @dev Call this function off-chain by using view
    function getPoolPendingReward() external returns (uint) {
        return gauge.claimable_reward_write(address(this), address(CRV));
    }

    function getUserPendingReward(address account, address rewardToken) external view returns (uint) {
        IReward reward = rewardInfo[rewardToken];
        (uint balance, uint rewardStartAt) = reward.userInfo(account);
        uint accRewardPerlpToken = reward.accRewardPerlpToken();
        return (balance * accRewardPerlpToken / 1e36) - rewardStartAt;
    }

    /// @return balance in LP (18 decimals)
    function getUserBalance(address account, address rewardToken) public view returns (uint balance) {
        IReward reward = rewardInfo[rewardToken];
        (balance,) = reward.userInfo(account);
    }

    function getUserBalanceInUSD(address account, address rewardToken) external view returns (uint) {
        uint userBalance = getUserBalance(account, rewardToken);
        return userBalance * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

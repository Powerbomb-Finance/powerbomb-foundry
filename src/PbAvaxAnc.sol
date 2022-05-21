// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "oz-upgradeable/security/PausableUpgradeable.sol";
import "oz-upgradeable/access/OwnableUpgradeable.sol";
import "oz-upgradeable/proxy/utils/Initializable.sol";
import "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IPool {
    function depositStable(address token, uint amount) external;
    function redeemStable(address token, uint amount) external;
}

interface IRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForAVAX(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
    returns (uint[] memory amounts);
}

interface ILendingPool {
    function supply(address asset, uint amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint amount, address to) external;
    function getReserveData(address asset) external view returns (
        uint, uint128, uint128, uint128, uint128, uint128, uint40, uint16, address
    );
}

interface IIncentivesController {
    function getAllUserRewards(address[] calldata assets, address user) external view returns(address[] memory, uint[] memory);
    function claimAllRewardsToSelf(address[] calldata assets) external returns (address[] memory, uint[] memory);
}

interface IChainlink {
    function latestRoundData() external view returns (uint, uint);
}

contract PbAvaxAnc is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant UST = IERC20Upgradeable(0xb599c3590F42f8F995ECfa0f85D2980B76862fc1);
    IERC20Upgradeable public constant aUST = IERC20Upgradeable(0xaB9A04808167C170A9EC4f8a87a0cD781ebcd55e);
    IERC20Upgradeable public constant WAVAX = IERC20Upgradeable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20Upgradeable public constant lpToken = IERC20Upgradeable(0xaB9A04808167C170A9EC4f8a87a0cD781ebcd55e); // aUST
    IERC20Upgradeable public rewardToken;

    IPool public constant pool = IPool(0x95aE712C309D33de0250Edd0C2d7Cb1ceAFD4550); // Anchor
    IRouter public constant router = IRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // Trader Joe
    IChainlink public constant oracle = IChainlink(0x9D5024F957AfD987FdDb0a7111C8c5352A3F274c); // aUST/UST
    address public treasury;
    
    uint public tvlMaxLimit;
    uint public basePool;
    uint public pendingHarvest;

    struct Fee {
        uint amount;
        bool claimInProgress;
        uint yieldFeePerc;
        uint withdrawFeePerc;
    }
    Fee public fees;

    uint public accRewardPerlpToken;
    ILendingPool public constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave Pool V3
    IIncentivesController public constant incentivesController = IIncentivesController(0x929EC64c34a17401F460460D4B9390518E5B473e); // To claim rewards
    IERC20Upgradeable public ibRewardToken; // aToken
    uint public lastIbRewardTokenAmt;

    struct User {
        uint balance;
        uint rewardStartAt;
        uint depositTime;
        uint pendingWithdraw;
    }
    mapping(address => User) public userInfo;
    mapping(address => uint) internal depositedBlock;

    event Deposit(address tokenDeposit, uint amountToken);
    event Withdraw(address tokenWithdraw, uint amountToken, address accountWithdraw);
    event Harvest(uint harvestedfarmToken, uint swappedRewardTokenAfterFee, uint fee);
    event ClaimReward(address receiver, uint claimedIbRewardTokenAfterFee, uint rewardToken);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetWithdrawFeePerc(uint oldWithdrawFeePerc, uint newWithdrawFeePerc);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);
    event SetTVLMaxLimit(uint oldTVLMaxLimit, uint newTVLMaxLimit);

    function initialize(IERC20Upgradeable _rewardToken, address _treasury) external virtual initializer {
        __Ownable_init();

        rewardToken = _rewardToken;
        treasury = _treasury;
        fees.yieldFeePerc = 500;
        fees.withdrawFeePerc = 10;
        (,,,,,,,,address ibRewardTokenAddr) = lendingPool.getReserveData(address(_rewardToken));
        ibRewardToken = IERC20Upgradeable(ibRewardTokenAddr);
        tvlMaxLimit = 5000000e6;

        UST.safeApprove(address(pool), type(uint).max);
        UST.safeApprove(address(router), type(uint).max);
        lpToken.safeApprove(address(pool), type(uint).max);
        rewardToken.safeApprove(address(lendingPool), type(uint).max);
        WAVAX.safeApprove(address(router), type(uint).max);
    }

    /// @dev Third parameter is reserved for slippage
    function deposit(IERC20Upgradeable token, uint amount, uint) external virtual nonReentrant whenNotPaused {
        require(token == UST, "Invalid token");
        require(amount >= 5e6, "Minimum 5 UST deposit");
        require(getAllPoolInUSD() + amount < tvlMaxLimit, "TVL max Limit reach");

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        User storage user = userInfo[msg.sender];
        user.balance += amount;
        user.rewardStartAt += (amount * accRewardPerlpToken / 1e36);
        user.depositTime = block.timestamp;
        basePool += amount;
        pool.depositStable(address(token), amount);

        emit Deposit(address(token), amount);
    }

    /// @dev Third parameter is reserved for slippage
    function withdraw(IERC20Upgradeable token, uint amount, uint) external virtual nonReentrant {
        require(token == UST, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(amount > 0 && user.balance >= amount, "Invalid amount to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        claimReward(msg.sender);

        user.balance = user.balance - amount;
        user.rewardStartAt = user.balance * accRewardPerlpToken / 1e36;
        basePool -= amount;

        // withdrawFeePerc or min 2 UST or max 100 UST as fee if withdraw within 1 week
        uint fee;
        if (user.depositTime + 604800 < block.timestamp) {
            fee = amount * fees.withdrawFeePerc / 10000;
            if (fee < 2e6) fee = 2e6;
            if (fee > 100e6) fee = 100e6;
        } else { // 2 UST as fee if withdraw after 1 week
            fee = 2e6;
        }
        amount -= fee;
        fees.amount += fee;

        user.pendingWithdraw += amount;
        (, uint rate) = oracle.latestRoundData();
        uint amtAUSTToRedeem = amount * 1e18 / rate;
        pool.redeemStable(address(aUST), amtAUSTToRedeem);

        emit Withdraw(address(token), amount, msg.sender);
    }

    /// @notice This function repay redeemed UST to depositor who trigger withdraw function
    function repayWithdraw(address receiver) external {
        uint _pendingWithdraw = userInfo[receiver].pendingWithdraw;
        require(_pendingWithdraw != 0, "No withdrawal");
        userInfo[receiver].pendingWithdraw = 0;
        UST.safeTransfer(receiver, _pendingWithdraw);
    }

    /// @notice There is no "harvest" function in Anchor, rewards is accumulated in UST
    function initializeHarvest() external virtual {
        // Calculate accumulate UST
        (, uint rate) = oracle.latestRoundData();
        uint accumulateUST = lpToken.balanceOf(address(this)) * rate / 1e18;

        // Calculate extra UST and record
        uint _basePool = basePool;
        pendingHarvest += accumulateUST - _basePool - fees.amount;

        // Calculate base pool in aUST
        uint aUSTBasePool = _basePool * 1e18 / rate;

        // Calculate extra aUST
        uint aUSTAmtToRedeem = lpToken.balanceOf(address(this)) - aUSTBasePool;

        // Withdraw rewards
        pool.redeemStable(address(lpToken), aUSTAmtToRedeem); // redeem with aUST
    }

    function harvest() external virtual nonReentrant {
        // Update accrued amount of ibRewardToken
        uint currentPool = getAllPool();
        uint ibRewardTokenAmt = ibRewardToken.balanceOf(address(this));
        uint accruedAmt;
        if (ibRewardTokenAmt > lastIbRewardTokenAmt) {
            accruedAmt = ibRewardTokenAmt - lastIbRewardTokenAmt;
            accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
        }

        // Swap UST to WAVAX
        uint harvestAmt = pendingHarvest;
        if (harvestAmt != 0) {
            pendingHarvest = 0;
            uint WAVAXAmt = swap2(address(UST), address(WAVAX), harvestAmt, 0);

            // Collect WAVAX reward from Aave
            address[] memory assets = new address[](1);
            assets[0] = address(ibRewardToken);
            (, uint[] memory unclaimedRewardsAmtList) = incentivesController.getAllUserRewards(assets, address(this)); // in WAVAX
            if (unclaimedRewardsAmtList[0] > 1e17) { // Approximately $8.0 @ 21 Apr 2022
                (, uint[] memory claimedAmounts) = incentivesController.claimAllRewardsToSelf(assets);
                WAVAXAmt += claimedAmounts[0];
            }

            // Swap WAVAX to rewardToken
            uint rewardTokenAmt = swap2(address(WAVAX), address(rewardToken), WAVAXAmt, 0);

            // Calculate fee
            uint fee = rewardTokenAmt * fees.yieldFeePerc / 10000;
            rewardTokenAmt -= fee;
            rewardToken.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (rewardTokenAmt * 1e36 / currentPool);

            // Supply reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(rewardToken), rewardTokenAmt, address(this), 0);

            // Update lastIbRewardTokenAmt
            lastIbRewardTokenAmt = ibRewardToken.balanceOf(address(this));

            emit Harvest(harvestAmt, rewardTokenAmt, fee);
        }
    }

    // function harvestWithParaswap(bytes calldata swapCalldata) public virtual {
    //     // TODO in future
    // }

    function claimReward(address account) public virtual {
        User storage user = userInfo[account];
        if (user.balance > 0) {
            // Calculate user reward
            uint ibRewardTokenAmt = (user.balance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (ibRewardTokenAmt > 0) {
                user.rewardStartAt += ibRewardTokenAmt;

                // Update lastIbRewardTokenAmt
                if (lastIbRewardTokenAmt > ibRewardTokenAmt) {
                    lastIbRewardTokenAmt -= ibRewardTokenAmt;
                } else {
                    lastIbRewardTokenAmt = 0;
                }

                // Withdraw ibRewardToken to rewardToken
                uint ibRewardTokenBal = ibRewardToken.balanceOf(address(this));
                if (ibRewardTokenBal > ibRewardTokenAmt) {
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenAmt, address(this));
                } else {
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenBal, address(this));
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = rewardToken.balanceOf(address(this));
                rewardToken.safeTransfer(account, rewardTokenAmt);

                emit ClaimReward(account, ibRewardTokenAmt, rewardTokenAmt);
            }
        }
    }

    function claimFees() external {
        Fee memory _fees = fees;
        require(!_fees.claimInProgress, "Claim in progress");
        (, uint rate) = oracle.latestRoundData();
        uint feesInAUST = _fees.amount * 1e18 / rate;
        fees.claimInProgress = true;
        pool.redeemStable(address(aUST), feesInAUST);
    }

    function repayFees() external {
        UST.safeTransfer(treasury, fees.amount);
        fees.claimInProgress = false;
        fees.amount = 0;
    }

    /// @param _tvlMaxLimit Max limit for TVL in this contract (6 decimals) 
    function setTVLMaxLimit(uint _tvlMaxLimit) external virtual onlyOwner {
        uint oldTVLMaxLimit = tvlMaxLimit;
        tvlMaxLimit = _tvlMaxLimit;

        emit SetTVLMaxLimit(oldTVLMaxLimit, _tvlMaxLimit);
    }

    function setTreasury(address _treasury) external virtual onlyOwner {
        address oldTreasury = treasury;
        treasury = _treasury;

        emit SetTreasury(oldTreasury, _treasury);
    }

    function pauseContract() external virtual onlyOwner {
        _pause();
    }

    function unpauseContract() external virtual onlyOwner {
        _unpause();
    }

    function swap2(address tokenIn, address tokenOut, uint amount, uint amountOutMin) internal virtual returns (uint) {
        return router.swapExactTokensForTokens(
            amount, amountOutMin, getPath(tokenIn, tokenOut), address(this), block.timestamp
        )[1];
    }

    function getPath(address tokenIn, address tokenOut) internal virtual pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
    }

    function getAllPool() public virtual view returns (uint) {
        return basePool; // 6 decimals
    }

    /// @return All pool in USD (6 decimals)
    function getAllPoolInUSD() public virtual view returns (uint) {
        return getAllPool();
    }

    /// @return ibRewardTokenAmt User pending reward (decimal follow reward token)
    function getUserPendingReward(address account) external virtual view returns (uint ibRewardTokenAmt) {
        User storage user = userInfo[account];
        ibRewardTokenAmt = (user.balance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    function getUserBalance(address account) external virtual view returns (uint) {
        return userInfo[account].balance; // 6 decimals
    }

    /// @return User balance in USD (6 decimals)
    function getUserBalanceInUSD(address account) external virtual view returns (uint) {
        return userInfo[account].balance;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    uint256[39] private __gap;
}
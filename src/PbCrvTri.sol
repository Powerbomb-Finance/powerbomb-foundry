// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "forge-std/Test.sol";

interface IRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

interface IPool {
    function add_liquidity(uint[3] memory amounts, uint _min_mint_amount) external;

    function remove_liquidity_one_coin(uint _token_amount, int128 i, uint _min_amount) external;
}

interface IGauge {
    function deposit(uint amount) external;
    function withdraw(uint amount) external;
    function claim_rewards() external;
    function claimable_reward(address _addr, address _token) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
}

interface IReward {
    function recordDeposit(address account, uint amount) external;

    function recordWithdraw(address account, uint amount) external;

    function harvest(uint amount) external;

    function claim(address account) external;

    function userInfo(address account) external view returns (uint balance, uint rewardStartAt);

    function accRewardPerlpToken() external view returns (uint);

    function getAllPool() external view returns (uint);
}

contract PbCrvTri is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant USDT = IERC20Upgradeable(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable constant crv3crypto = IERC20Upgradeable(0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2);
    IPool constant pool = IPool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    IGauge constant gauge = IGauge(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    IRouter constant router = IRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // Sushi

    address[] public rewards;

    struct User {
        uint lpTokenBalance;
        uint rewardStartAt;
    }
    mapping(address => User) public userInfo;
    mapping(address => uint) private depositedBlock;
    mapping(address => IReward) public rewardInfo;

    event Deposit(address tokenDeposit, uint amountToken, uint amountlpToken);
    event Withdraw(address tokenWithdraw, uint amountToken);
    event Harvest(uint harvestedfarmToken, uint swappedRewardTokenAfterFee, uint fee);
    event ClaimReward(address receiver, uint claimedIbRewardTokenAfterFee, uint rewardToken);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);

    function initialize() external initializer {
        __Ownable_init();


        USDT.safeApprove(address(pool), type(uint).max);
        WBTC.safeApprove(address(pool), type(uint).max);
        WETH.safeApprove(address(pool), type(uint).max);
        crv3crypto.safeApprove(address(gauge), type(uint).max);
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
        reward.recordDeposit(msg.sender, amount);
        // emit Deposit(address(token), amount, crv3cryptoAmt);
    }

    // function withdraw(IERC20Upgradeable token, uint amountOutLpToken, uint slippage) external nonReentrant {
    //     require(token == USDT || token == USDC || token == DAI || token == lpToken, "Invalid token");
    //     User storage user = userInfo[msg.sender];
    //     require(amountOutLpToken > 0 && user.lpTokenBalance >= amountOutLpToken, "Invalid amountOutLpToken to withdraw");
    // }

    function harvest() public {
        gauge.claim_rewards();
        uint CRVAmt = CRV.balanceOf(address(this));
        // console.log(CRV.balanceOf(address(this))); // 11.863594254423020207

        uint allPool = getAllPool();

        for (uint i; i < rewards.length; i++) {
            if (rewards[i] != address(0)) {
                IReward reward = IReward(rewards[i]);
                uint rewardPool = reward.getAllPool();
                uint poolPerc = rewardPool * 10000 / allPool;
                uint poolCRVAmt = poolPerc * CRVAmt / 10000;
                reward.harvest(poolCRVAmt);
            }
        }
    }

    // function claimReward(address account) public nonReentrant {
        
    // }

    // function swap(address tokenIn, address tokenOut, uint amount) private returns (uint) {
    //     address[] memory path = getPath(tokenIn, tokenOut);
    //     return router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp)[1];
    // }

    // function pauseContract() external onlyOwner {
    //     _pause();
    // }

    // function unpauseContract() external onlyOwner {
    //     _unpause();
    // }

    // function setTreasury(address _treasury) external onlyOwner {
    //     emit SetTreasury(treasury, _treasury);
    //     treasury = _treasury;
    // }


    function setNewReward(address reward, address rewardToken) external onlyOwner {
        rewardInfo[rewardToken] = IReward(reward);
        rewards.push(reward);
        CRV.safeApprove(reward, type(uint).max);
    }

    function removeReward(uint index) external onlyOwner {
        CRV.safeApprove(address(rewards[index]), 0);
        rewards[index] = address(0);
    }

    // function getPath(address tokenIn, address tokenOut) private pure returns (address[] memory path) {
    //     path = new address[](2);
    //     path[0] = tokenIn;
    //     path[1] = tokenOut;
    // }

    // /// @return Price per full share in USD (6 decimals)
    // function getPricePerFullShareInUSD() public view returns (uint) {
    //     return pool_price() / 1e12;
    // }

    function getAllPool() public view returns (uint) {
        return gauge.balanceOf(address(this));
    }

    // /// @return All pool in USD (6 decimals)
    // function getAllPoolInUSD() public view returns (uint) {
    //     uint allPool = getAllPool();
    //     if (allPool == 0) return 0;
    //     return allPool * getPricePerFullShareInUSD() / 1e18;
    // }

    // function getPoolPendingReward(IERC20Upgradeable pendingRewardToken) external returns (uint) {
    //     uint pendingRewardFromCurve = gauge.claimable_reward_write(address(this), address(pendingRewardToken));
    //     return pendingRewardFromCurve + pendingRewardToken.balanceOf(address(this));
    // }

    // /// @return ibRewardTokenAmt User pending reward (decimal follow reward token)
    // function getUserPendingReward(address account) external view returns (uint ibRewardTokenAmt) {
    //     User storage user = userInfo[account];
    //     ibRewardTokenAmt = (user.lpTokenBalance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
    // }

    function getUserPendingReward(address account, address rewardToken) external view returns (uint) {
        IReward reward = rewardInfo[rewardToken];
        (uint balance, uint rewardStartAt) = reward.userInfo(account);
        uint accRewardPerlpToken = reward.accRewardPerlpToken();
        return (balance * accRewardPerlpToken / 1e36) - rewardStartAt;
    }

    // /// @return User balance in LP (18 decimals)
    // function getUserBalance(address account) external view returns (uint) {
    //     return userInfo[account].lpTokenBalance;
    // }

    // /// @return User balance in USD (6 decimals)
    // function getUserBalanceInUSD(address account) external view returns (uint) {
    //     return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() / 1e18;
    // }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

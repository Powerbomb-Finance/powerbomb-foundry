// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IPair.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IChainLink.sol";

contract PbVelo is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;
    using SafeERC20Upgradeable for IPair;

    IERC20Upgradeable constant VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IRouter constant router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IChainLink constant WETHPriceFeed = IChainLink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    ILendingPool constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;
    IPair public lpToken;
    IGauge public gauge;
    bool public stable;
    address public treasury;
    uint public yieldFeePerc; // 2 decimals, 50 = 0.5%

    struct Reward {
        IERC20Upgradeable rewardToken;
        IERC20Upgradeable aToken;
        uint lastATokenAmt;
        uint accRewardPerlpToken;
    }
    Reward public reward;

    struct User {
        uint lpTokenBalance;
        uint rewardStartAt;
    }
    mapping(address => User) public userInfo;
    mapping(address => uint) internal depositedBlock;

    event Deposit(address indexed tokenDeposit, uint amountToken, uint amountlpToken);
    event Withdraw(address indexed tokenWithdraw, uint amountToken);
    event Harvest(uint harvestedfarmToken, uint swappedRewardTokenAfterFee, uint fee);
    event Claim(address receiver, uint claimedATokenAmt, uint claimedRewardTokenAmt);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);

    function initialize(
        IGauge _gauge,
        IERC20Upgradeable _rewardToken,
        address _treasury
    ) external virtual initializer {
        __Ownable_init();

        gauge = _gauge;
        address _lpToken = gauge.stake();
        lpToken = IPair(_lpToken);
        (address _token0, address _token1) = lpToken.tokens();
        token0 = IERC20Upgradeable(_token0);
        token1 = IERC20Upgradeable(_token1);
        stable = lpToken.stable();
        reward.rewardToken = _rewardToken;
        (,,,,,,,,address _aTokenAddr) = lendingPool.getReserveData(address(_rewardToken));
        reward.aToken = IERC20Upgradeable(_aTokenAddr);
        treasury = _treasury;
        yieldFeePerc = 50; // 2 decimals, 50 = 0.5%

        token0.safeApprove(address(router), type(uint).max);
        token1.safeApprove(address(router), type(uint).max);
        lpToken.safeApprove(address(router), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        VELO.safeApprove(address(router), type(uint).max);
        reward.rewardToken.safeApprove(address(lendingPool), type(uint).max);

        if (WETH.allowance(address(this), address(router)) == 0) {
            WETH.safeApprove(address(router), type(uint).max);
        }
    }

    function deposit(
        IERC20Upgradeable token, uint amount, uint swapPerc, uint amountOutMin
    ) external payable virtual nonReentrant whenNotPaused {
        require(token == token0 || token == token1 || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = getAllPool();
        if (currentPool > 0) harvest();

        uint token0AmtBef = token0.balanceOf(address(this));
        uint token1AmtBef = token1.balanceOf(address(this));

        if (msg.value != 0) {
            require(amount == msg.value, "Invalid ETH amount");
            WETH.deposit{value: msg.value}();
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            (uint amountA, uint amountB) = (0, 0);
            if (token == token0) {
                amountA = amount * swapPerc / 1000;
                amountB = swap(address(token0), address(token1), stable, amountA, amountOutMin);
                amountA = amount - amountA;
            } else {
                amountB = amount * swapPerc / 1000;
                amountA = swap(address(token1), address(token0), stable, amountB, amountOutMin);
                amountB = amount - amountB;
            }
            (,,lpTokenAmt) = router.addLiquidity(
                address(token0), address(token1), stable, amountA, amountB, 0, 0, address(this), block.timestamp
            );

            uint token0AmtLeft = token0.balanceOf(address(this)) - token0AmtBef;
            if (token0AmtLeft > 0) token0.safeTransfer(msg.sender, token0AmtLeft);
            uint token1AmtLeft = token1.balanceOf(address(this)) - token1AmtBef;
            if (token1AmtLeft > 0) token1.safeTransfer(msg.sender, token1AmtLeft);

        } else {
            lpTokenAmt = amount;
        }

        gauge.deposit(lpTokenAmt, 0);
        User storage user = userInfo[msg.sender];
        user.lpTokenBalance += lpTokenAmt;
        user.rewardStartAt += (lpTokenAmt * reward.accRewardPerlpToken / 1e36);

        emit Deposit(address(token), amount, lpTokenAmt);
    }

    function withdraw(IERC20Upgradeable token, uint amountOutLpToken, uint amountOutMin) external {
        uint amountOutToken = _withdraw(token, amountOutLpToken, amountOutMin);
        token.safeTransfer(msg.sender, amountOutToken);
    }

    function withdrawETH(IERC20Upgradeable token, uint amountOutLpToken, uint amountOutMin) external {
        require(token0 == WETH || token1 == WETH, "Withdraw ETH not valid");
        uint WETHAmt = _withdraw(token, amountOutLpToken, amountOutMin);
        WETH.withdraw(WETHAmt);
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    receive() external payable {}

    function _withdraw(
        IERC20Upgradeable token, uint amountOutLpToken, uint amountOutMin
    ) internal virtual nonReentrant returns (uint amountOutToken) {
        require(token == token0 || token == token1 || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(amountOutLpToken > 0 && user.lpTokenBalance >= amountOutLpToken, "Invalid amountOutLpToken to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        harvest();

        user.lpTokenBalance = user.lpTokenBalance - amountOutLpToken;
        user.rewardStartAt = user.lpTokenBalance * reward.accRewardPerlpToken / 1e36;
        gauge.withdraw(amountOutLpToken);

        if (token != lpToken) {
            (uint token0Amt, uint token1Amt) = router.removeLiquidity(
                address(token0), address(token1), stable, amountOutLpToken, 0, 0, address(this), block.timestamp
            );
            if (token == token0) {
                token0Amt += swap(address(token1), address(token0), stable, token1Amt, amountOutMin);
                amountOutToken = token0Amt;
            } else {
                token1Amt += swap(address(token0), address(token1), stable, token0Amt, amountOutMin);
                amountOutToken = token1Amt;
            }
        } else {
            amountOutToken = amountOutLpToken;
        }

        emit Withdraw(address(token), amountOutToken);
    }

    function harvest() public virtual {
        uint currentPool = getAllPool();

        // Update accrued amount of aToken
        uint aTokenAmt = reward.aToken.balanceOf(address(this));
        if (aTokenAmt > reward.lastATokenAmt) {
            uint accruedAmt = aTokenAmt - reward.lastATokenAmt;
            reward.accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
            reward.lastATokenAmt = aTokenAmt;
        }

        // Collect VELO from gauge
        address[] memory tokens = new address[](1);
        tokens[0] = address(lpToken);
        gauge.getReward(address(this), tokens);

        uint VELOAmt = VELO.balanceOf(address(this));
        uint WETHAmt;
        if (VELOAmt > 0) {
            (WETHAmt,) = router.getAmountOut(VELOAmt, address(VELO), address(WETH));
        }
        if (WETHAmt > 1e16) { // 0.01 WETH, ~$15 on 28 July 2022
            // Swap VELO to WETH
            WETHAmt = swap(address(VELO), address(WETH), false, VELOAmt, 0);

            // Swap WETH to reward token
            uint rewardTokenAmt;
            if (reward.rewardToken == WBTC) {
                IRouter.route[] memory routes = new IRouter.route[](2);
                routes[0] = IRouter.route(address(WETH), address(USDC), false);
                routes[1] = IRouter.route(address(USDC), address(WBTC), false);
                rewardTokenAmt = router.swapExactTokensForTokens(
                    WETHAmt,
                    0,
                    routes,
                    address(this),
                    block.timestamp
                )[2];

            } else if (reward.rewardToken == USDC) {
                rewardTokenAmt = swap(address(WETH), address(reward.rewardToken), false, WETHAmt, 0);

            } else { // reward.rewardToken == WETH
                rewardTokenAmt = WETHAmt;
            }

            // Calculate fee
            uint fee = rewardTokenAmt * yieldFeePerc / 10000;
            rewardTokenAmt -= fee;
            reward.rewardToken.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            reward.accRewardPerlpToken += (rewardTokenAmt * 1e36 / currentPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(reward.rewardToken), rewardTokenAmt, address(this), 0);

            // Update lastATokenAmt
            reward.lastATokenAmt = reward.aToken.balanceOf(address(this));

            emit Harvest(VELOAmt, rewardTokenAmt, fee);
        }
    }

    function claim() external nonReentrant {
        harvest();

        User storage user = userInfo[msg.sender];
        if (user.lpTokenBalance > 0) {
            // Calculate user reward
            uint aTokenAmt = (user.lpTokenBalance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (aTokenAmt > 0) {
                user.rewardStartAt += aTokenAmt;

                // Withdraw aToken to rewardToken
                uint aTokenBal = reward.aToken.balanceOf(address(this));
                if (aTokenBal > aTokenAmt) {
                    lendingPool.withdraw(address(reward.rewardToken), aTokenAmt, address(this));
                } else {
                    // Last withdrawal
                    lendingPool.withdraw(address(reward.rewardToken), aTokenBal, address(this));
                }

                // Update lastATokenAmt
                if (reward.lastATokenAmt > aTokenAmt) {
                    reward.lastATokenAmt -= aTokenAmt;
                } else {
                    // Last withdrawal
                    reward.lastATokenAmt = 0;
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = reward.rewardToken.balanceOf(address(this));
                reward.rewardToken.safeTransfer(msg.sender, rewardTokenAmt);

                emit Claim(msg.sender, aTokenAmt, rewardTokenAmt);
            }
        }
    }

    function swap(
        address tokenIn, address tokenOut, bool _stable, uint amount, uint amountOutMin
    ) internal returns (uint) {
        return router.swapExactTokensForTokensSimple(
            amount, amountOutMin, tokenIn, tokenOut, _stable, address(this), block.timestamp
        )[1];
    }

    function getLpTokenPriceInETH() internal view returns (uint) {
        (uint reserveToken0, uint reserveToken1) = lpToken.getReserves();

        uint totalReserveTokenInETH;
        uint token0Decimals = uint(IERC20MetadataUpgradeable(address(token0)).decimals());
        uint token1Decimals = uint(IERC20MetadataUpgradeable(address(token1)).decimals());
        if (token0 == WETH) {
            (uint token1PriceInETH,) = router.getAmountOut(10 ** token1Decimals, address(token1), address(WETH));
            uint reserveToken1InETH = reserveToken1 * token1PriceInETH / 10 ** token1Decimals;
            totalReserveTokenInETH = reserveToken0 + reserveToken1InETH;
        } else if (token1 == WETH) {
            (uint token0PriceInETH,) = router.getAmountOut(10 ** token0Decimals, address(token0), address(WETH));
            uint reserveToken0InETH = reserveToken0 * token0PriceInETH / 10 ** token0Decimals;
            totalReserveTokenInETH = reserveToken1 + reserveToken0InETH;
        } else {
            (uint token0PriceInETH,) = router.getAmountOut(10 ** token0Decimals, address(token0), address(WETH));
            uint reserveToken0InETH = reserveToken0 * token0PriceInETH / 10 ** token0Decimals;

            (uint token1PriceInETH,) = router.getAmountOut(10 ** token1Decimals, address(token1), address(WETH));
            uint reserveToken1InETH = reserveToken1 * token1PriceInETH / 10 ** token1Decimals;

            totalReserveTokenInETH = reserveToken0InETH + reserveToken1InETH;
        }

        return totalReserveTokenInETH * 1e18 / lpToken.totalSupply();
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function setTreasury(address _treasury) external onlyOwner {
        emit SetTreasury(treasury, _treasury);
        treasury = _treasury;
    }

    function setYieldFeePerc(uint _yieldFeePerc) external onlyOwner {
        require(_yieldFeePerc <= 1000, "Fee cannot over 10%");
        emit SetYieldFeePerc(yieldFeePerc, _yieldFeePerc);
        yieldFeePerc = _yieldFeePerc;
    }

    function getPricePerFullShareInUSD() public view virtual returns (uint) {
        (, int rawPrice,,,) = WETHPriceFeed.latestRoundData();

        return getLpTokenPriceInETH() * uint(rawPrice) / 1e20; // 6 decimals
    }

    function getAllPool() public view returns (uint) {
        return gauge.balanceOf(address(this));
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function getPoolPendingReward() external view returns (uint) {
        return gauge.earned(address(lpToken), address(this));
    }

    /// @return aTokenAmt User pending reward (decimal follow reward token)
    function getUserPendingReward(address account) external view returns (uint aTokenAmt) {
        User storage user = userInfo[account];
        aTokenAmt = (user.lpTokenBalance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    function getUserBalance(address account) external view virtual returns (uint) {
        return userInfo[account].lpTokenBalance;
    }

    function getUserBalanceInUSD(address account) external view virtual returns (uint) {
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

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

import "forge-std/Test.sol";

contract PbVelo is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;
    using SafeERC20Upgradeable for IPair;

    IERC20Upgradeable public VELO;
    IRouter public router;
    IWETH public WETH;
    IERC20Upgradeable public USDC;
    IChainLink public WETHPriceFeed;
    ILendingPool public lendingPool;
    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;
    IPair public lpToken;
    IGauge public gauge;
    bool public stable;
    address public treasury;
    uint public yieldFeePerc; // 2 decimals, 50 = 0.5%

    struct Reward {
        IERC20Upgradeable rewardToken;
        IERC20Upgradeable ibRewardToken; // aToken
        uint lastIbRewardTokenAmt;
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
    event ClaimReward(address receiver, uint claimedIbRewardTokenAmt, uint claimedRewardTokenAmt);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);

    function initialize(
        IERC20Upgradeable _VELO,
        IGauge _gauge,
        IERC20Upgradeable _rewardToken,
        ILendingPool _lendingPool,
        IRouter _router,
        IWETH _WETH,
        IChainLink _WETHPriceFeed,
        address _treasury
    ) external virtual initializer {
        __Ownable_init();

        VELO = _VELO;
        gauge = _gauge;
        address _lpToken = gauge.stake();
        lpToken = IPair(_lpToken);
        (address _token0, address _token1) = lpToken.tokens();
        token0 = IERC20Upgradeable(_token0);
        token1 = IERC20Upgradeable(_token1);
        stable = lpToken.stable();
        reward.rewardToken = _rewardToken;
        lendingPool = _lendingPool;
        (,,,,,,,,address _ibRewardTokenAddr) = lendingPool.getReserveData(address(_rewardToken));
        reward.ibRewardToken = IERC20Upgradeable(_ibRewardTokenAddr);
        router = _router;
        WETH = _WETH;
        WETHPriceFeed = _WETHPriceFeed;
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

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable virtual nonReentrant whenNotPaused {
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
            if (token == token0) {
                uint halfToken0Amt = amount / 2;
                uint token1Amt = swap(address(token0), address(token1), stable, halfToken0Amt, amountOutMin);
                (,,lpTokenAmt) = router.addLiquidity(
                    address(token0), address(token1), stable, halfToken0Amt, token1Amt, 0, 0, address(this), block.timestamp
                );
            } else {
                uint halfToken1Amt = amount / 2;
                uint token0Amt = swap(address(token1), address(token0), stable, halfToken1Amt, amountOutMin);
                (,,lpTokenAmt) = router.addLiquidity(
                    address(token0), address(token1), stable, token0Amt, halfToken1Amt, 0, 0, address(this), block.timestamp
                );
            }

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
        require(token0 == WETH || token1  == WETH, "Withdraw ETH not valid");
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

        // Update accrued amount of ibRewardToken
        uint ibRewardTokenAmt = reward.ibRewardToken.balanceOf(address(this));
        if (ibRewardTokenAmt > reward.lastIbRewardTokenAmt) {
            uint accruedAmt = ibRewardTokenAmt - reward.lastIbRewardTokenAmt;
            reward.accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
            reward.lastIbRewardTokenAmt = ibRewardTokenAmt;
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
        if (WETHAmt > 1e16) { // 0.01 WETH, ~$20 on 31 May 2022
            // Swap VELO to WETH
            WETHAmt = swap(address(VELO), address(WETH), false, VELOAmt, 0);

            // Swap WETH to reward token
            uint rewardTokenAmt;
            if (reward.rewardToken != WETH) {
                rewardTokenAmt = swap(address(WETH), address(reward.rewardToken), false, WETHAmt, 0);
            } else {
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

            // Update lastIbRewardTokenAmt
            reward.lastIbRewardTokenAmt = reward.ibRewardToken.balanceOf(address(this));

            emit Harvest(VELOAmt, rewardTokenAmt, fee);
        }
    }

    function claimReward(address account) public nonReentrant {
        harvest();

        User storage user = userInfo[account];
        if (user.lpTokenBalance > 0) {
            // Calculate user reward
            uint ibRewardTokenAmt = (user.lpTokenBalance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (ibRewardTokenAmt > 0) {
                user.rewardStartAt += ibRewardTokenAmt;

                // Withdraw ibRewardToken to rewardToken
                uint ibRewardTokenBal = reward.ibRewardToken.balanceOf(address(this));
                if (ibRewardTokenBal > ibRewardTokenAmt) {
                    lendingPool.withdraw(address(reward.rewardToken), ibRewardTokenAmt, address(this));
                } else {
                    lendingPool.withdraw(address(reward.rewardToken), ibRewardTokenBal, address(this));
                }

                // Update lastIbRewardTokenAmt
                if (reward.lastIbRewardTokenAmt > ibRewardTokenAmt) {
                    reward.lastIbRewardTokenAmt -= ibRewardTokenAmt;
                } else {
                     // Last withdrawal
                    reward.lastIbRewardTokenAmt = 0;
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = reward.rewardToken.balanceOf(address(this));
                reward.rewardToken.safeTransfer(account, rewardTokenAmt);

                emit ClaimReward(account, ibRewardTokenAmt, rewardTokenAmt);
            }
        }
    }

    function swap(address tokenIn, address tokenOut, bool _stable, uint amount, uint amountOutMin) internal returns (uint) {
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

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    function setTreasury(address _treasury) external onlyOwner {
        address oldTreasury = treasury;
        treasury = _treasury;

        emit SetTreasury(oldTreasury, _treasury);
    }

    function setYieldFeePerc(uint _yieldFeePerc) external onlyOwner {
        require(_yieldFeePerc <= 1000, "Fee cannot over 10%");
        uint oldYieldFeePerc = yieldFeePerc;
        yieldFeePerc = _yieldFeePerc;

        emit SetYieldFeePerc(oldYieldFeePerc, _yieldFeePerc);
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

    /// @return ibRewardTokenAmt User pending reward (decimal follow reward token)
    function getUserPendingReward(address account) external view returns (uint ibRewardTokenAmt) {
        User storage user = userInfo[account];
        ibRewardTokenAmt = (user.lpTokenBalance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    function getUserBalance(address account) external view virtual returns (uint) {
        return userInfo[account].lpTokenBalance;
    }

    function getUserBalanceInUSD(address account) external view virtual returns (uint) {
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

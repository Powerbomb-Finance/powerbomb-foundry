// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PbCrvBase.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IZap.sol";
import "../interface/IMinter.sol";
import "../interface/IRewardsController.sol";

contract PbCrvOpUsd is PbCrvBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant USDT = IERC20Upgradeable(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    IERC20Upgradeable constant DAI = IERC20Upgradeable(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20Upgradeable constant SUSD = IERC20Upgradeable(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IERC20Upgradeable constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IZap constant zap = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    IMinter constant minter = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    IRewardsController constant rewardsController = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);

    function initialize(IERC20Upgradeable _rewardToken, address _treasury) external initializer {
        __Ownable_init();

        CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
        lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
        rewardToken = _rewardToken;
        pool = IPool(0x061b87122Ed14b9526A813209C8a59a633257bAb);
        gauge = IGauge(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
        treasury = _treasury;
        yieldFeePerc = 500;
        lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        USDC.safeApprove(address(zap), type(uint).max);
        USDT.safeApprove(address(zap), type(uint).max);
        DAI.safeApprove(address(zap), type(uint).max);
        SUSD.safeApprove(address(zap), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        lpToken.safeApprove(address(zap), type(uint).max);
        CRV.safeApprove(address(swapRouter), type(uint).max);
        rewardToken.safeApprove(address(lendingPool), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable override nonReentrant whenNotPaused {
        require(token == SUSD || token == DAI || token == USDC || token == USDT || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[4] memory amounts;
            if (token == SUSD) amounts[0] = amount;
            else if (token == DAI) amounts[1] = amount;
            else if (token == USDC) amounts[2] = amount;
            else amounts[3] = amount; // token == USDT
            lpTokenAmt = zap.add_liquidity(address(pool), amounts, amountOutMin);
        } else {
            lpTokenAmt = amount;
        }

        gauge.deposit(lpTokenAmt);
        User storage user = userInfo[msg.sender];
        user.lpTokenBalance += lpTokenAmt;
        user.rewardStartAt += (lpTokenAmt * accRewardPerlpToken / 1e36);

        emit Deposit(msg.sender, address(token), amount, lpTokenAmt);
    }

    function withdraw(IERC20Upgradeable token, uint lpTokenAmt, uint amountOutMin) external payable override nonReentrant {
        require(token == SUSD || token == DAI || token == USDC || token == USDT || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(lpTokenAmt > 0 && user.lpTokenBalance >= lpTokenAmt, "Invalid lpTokenAmt to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        claim();

        user.lpTokenBalance = user.lpTokenBalance - lpTokenAmt;
        user.rewardStartAt = user.lpTokenBalance * accRewardPerlpToken / 1e36;
        gauge.withdraw(lpTokenAmt);

        uint tokenAmt;
        if (token != lpToken) {
            int128 i;
            if (token == SUSD) i = 0;
            else if (token == DAI) i = 1;
            else if (token == USDC) i = 2;
            else i = 3; // USDT
            tokenAmt = zap.remove_liquidity_one_coin(address(pool), lpTokenAmt, i, amountOutMin);
        } else {
            tokenAmt = lpTokenAmt;
        }
        token.safeTransfer(msg.sender, tokenAmt);

        emit Withdraw(msg.sender, address(token), lpTokenAmt, tokenAmt);
    }

    function harvest() public override {
        // Update accrued amount of aToken
        uint allPool = getAllPool();
        uint aTokenAmt = aToken.balanceOf(address(this));
        if (aTokenAmt > lastATokenAmt) {
            uint accruedAmt = aTokenAmt - lastATokenAmt;
            accRewardPerlpToken += (accruedAmt * 1e36 / allPool);
            lastATokenAmt = aTokenAmt;
        }

        // Claim CRV from Curve
        minter.mint(address(gauge)); // to claim crv
        gauge.claim_rewards(); // to claim op

        // Claim OP from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        rewardsController.claimRewards(assets, type(uint).max, address(this), address(OP));

        uint CRVAmt = CRV.balanceOf(address(this));
        uint OPAmt = OP.balanceOf(address(this));
        if (CRVAmt > 1e18 || OPAmt > 1e18) {
            uint rewardTokenAmt;

            // Swap CRV to WETH
            if (CRVAmt > 1e18) {
                rewardTokenAmt = swapRouter.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(CRV),
                        tokenOut: address(WETH),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: CRVAmt,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
            }

            // Swap OP to WETH
            if (OPAmt > 1 ether) {
                rewardTokenAmt += swapRouter.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(OP),
                        tokenOut: address(WETH),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: OPAmt,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
            }

            // Swap WETH to WBTC if rewardToken == WBTC
            if (rewardToken == WBTC) {
                rewardTokenAmt = swapRouter.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(WETH),
                        tokenOut: address(WBTC),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: rewardTokenAmt,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
            }

            // Calculate fee
            uint fee = rewardTokenAmt * yieldFeePerc / 10000;
            rewardTokenAmt -= fee;
            rewardToken.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (rewardTokenAmt * 1e36 / allPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(rewardToken), rewardTokenAmt, address(this), 0);

            // Update lastATokenAmt
            lastATokenAmt = aToken.balanceOf(address(this));

            emit Harvest(CRVAmt, rewardTokenAmt, fee);
        }
    }

    function claim() public override {
        harvest();

        User storage user = userInfo[msg.sender];
        if (user.lpTokenBalance > 0) {
            // Calculate user reward
            uint aTokenAmt = (user.lpTokenBalance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (aTokenAmt > 0) {
                user.rewardStartAt += aTokenAmt;

                // Update lastATokenAmt
                if (lastATokenAmt >= aTokenAmt) {
                    lastATokenAmt -= aTokenAmt;
                } else {
                    // Last claim: to prevent arithmetic underflow error due to minor variation
                    lastATokenAmt = 0;
                }

                // Withdraw aToken to rewardToken
                uint aTokenBal = aToken.balanceOf(address(this));
                if (aTokenBal >= aTokenAmt) {
                    lendingPool.withdraw(address(rewardToken), aTokenAmt, address(this));
                } else {
                    // Last withdraw: to prevent withdrawal fail from lendingPool due to minor variation
                    lendingPool.withdraw(address(rewardToken), aTokenBal, address(this));
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = rewardToken.balanceOf(address(this));
                rewardToken.safeTransfer(msg.sender, rewardTokenAmt);

                emit Claim(msg.sender, rewardTokenAmt);
            }
        }
    }

    function getPricePerFullShareInUSD() public view override returns (uint) {
        return pool.get_virtual_price() / 1e12; // 6 decimals
    }

    function getAllPool() public view override returns (uint) {
        return gauge.balanceOf(address(this)); // lpToken, 18 decimals
    }

    function getAllPoolInUSD() external view override returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    /// @dev to override base contract (compulsory)
    function getPoolPendingReward() external pure override returns (uint) {
        return 0;
    }

    /// @dev Call this function off-chain by using view
    function getPoolPendingReward2() external returns (uint crvReward, uint opReward) {
        crvReward = gauge.claimable_tokens(address(this)) + CRV.balanceOf(address(this));
        opReward = gauge.claimable_reward(address(this), address(OP)) + OP.balanceOf(address(this));
    }

    function getUserPendingReward(address account) external view override returns (uint) {
        User storage user = userInfo[account];
        return (user.lpTokenBalance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    function getUserBalance(address account) external view override returns (uint) {
        return userInfo[account].lpTokenBalance;
    }

    function getUserBalanceInUSD(address account) external view override returns (uint) {
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() / 1e18;
    }
}

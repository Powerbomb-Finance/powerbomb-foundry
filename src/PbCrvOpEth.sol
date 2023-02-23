// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./PbCrvBase.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IQuoter.sol";
import "../interface/IZap.sol";
import "../interface/IMinter.sol";
import "../interface/IRewardsController.sol";
import "../interface/IChainlink.sol";

contract PbCrvOpEth is PbCrvBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant SETH = IERC20Upgradeable(0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    ISwapRouter constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter constant QUOTER = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    IMinter constant MINTER = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    IRewardsController constant REWARDS_CONTROLLER = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
    IChainlink constant ETH_USD_PRICE_ORACLE = IChainlink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function initialize(IERC20Upgradeable rewardToken_, address treasury_) external initializer {
        require(treasury_ != address(0));
        __Ownable_init();

        CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
        lpToken = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
        rewardToken = rewardToken_;
        pool = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
        gauge = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
        treasury = treasury_;
        yieldFeePerc = 500;
        lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        SETH.safeApprove(address(pool), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        lpToken.safeApprove(address(pool), type(uint).max);
        CRV.safeApprove(address(SWAP_ROUTER), type(uint).max);
        OP.safeApprove(address(SWAP_ROUTER), type(uint).max);
        WETH.safeApprove(address(SWAP_ROUTER), type(uint).max);
        rewardToken.safeApprove(address(lendingPool), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable override nonReentrant whenNotPaused {
        require(token == WETH || token == SETH || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        if (token == WETH) {
            require(msg.value == amount, "Invalid ETH");
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[2] memory amounts;
            if (token == WETH) amounts[0] = amount;
            else amounts[1] = amount; // token == SETH
            lpTokenAmt = pool.add_liquidity{value: msg.value}(amounts, amountOutMin);
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
        require(token == WETH || token == SETH || token == lpToken, "Invalid token");
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
            if (token == WETH) i = 0;
            else i = 1; // SETH
            tokenAmt = pool.remove_liquidity_one_coin(lpTokenAmt, i, amountOutMin, msg.sender);
        } else {
            tokenAmt = lpTokenAmt;
            token.safeTransfer(msg.sender, lpTokenAmt);
        }

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
        MINTER.mint(address(gauge)); // to claim CRV
        gauge.claim_rewards(); // to claim op

        // Claim OP from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        REWARDS_CONTROLLER.claimRewards(assets, type(uint).max, address(this), address(OP));

        uint crvAmt = CRV.balanceOf(address(this));
        uint OPAmt = OP.balanceOf(address(this));
        if (crvAmt > 1 ether || OPAmt > 1 ether) {
            uint wethAmt = 0;

            // Swap CRV and OP to WETH
            if (crvAmt > 1 ether) {
                wethAmt = SWAP_ROUTER.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(CRV),
                        tokenOut: address(WETH),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: crvAmt,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
            }

            if (OPAmt > 1 ether) {
                wethAmt += SWAP_ROUTER.exactInputSingle(
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

            // Swap WETH to rewardToken if rewardToken != WETH
            uint rewardTokenAmt = 0;
            if (rewardToken != WETH) {
                rewardTokenAmt += SWAP_ROUTER.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(WETH),
                        tokenOut: address(rewardToken),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: wethAmt,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
            } else {
                rewardTokenAmt = wethAmt;
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

            // Update accumulate reward token amount
            accRewardTokenAmt += rewardTokenAmt;

            emit Harvest(crvAmt, rewardTokenAmt, fee);
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

    function getAllPoolInUSD() external view override returns (uint allPoolInUSD) {
        uint allPool = getAllPool();
        if (allPool > 0) {
            (, int latestPrice,,,) = ETH_USD_PRICE_ORACLE.latestRoundData();
            allPoolInUSD = allPool * getPricePerFullShareInUSD() * uint(latestPrice) / 1e26; // 6 decimals
        }
    }

    /// @dev to override base contract (compulsory)
    function getPoolPendingReward() external pure override returns (uint) {
        return 0;
    }

    /// @dev Call this function off-chain by using view
    function getPoolPendingReward2() public returns (uint crvReward, uint opReward) {
        crvReward = gauge.claimable_tokens(address(this)) + CRV.balanceOf(address(this));
        opReward = gauge.claimable_reward(address(this), address(OP)) + OP.balanceOf(address(this));
    }

    /// @dev This function only return user pending reward that harvested
    function getUserPendingReward(address account) external view override returns (uint) {
        User storage user = userInfo[account];
        return (user.lpTokenBalance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    /// @dev This function return estimated user pending reward including reward that ready to harvest
    function getUserPendingReward2(address account) external returns (uint) {
        (uint crvReward, uint opReward) = getPoolPendingReward2();
        uint accRewardPerlpToken_ = accRewardPerlpToken;
        uint wethAmt = 0;
        if (crvReward > 1 ether) {
            wethAmt = QUOTER.quoteExactInputSingle(address(CRV), address(WETH), 3000, crvReward, 0);
        }
        if (opReward > 1 ether) {
            wethAmt += QUOTER.quoteExactInputSingle(address(OP), address(WETH), 3000, opReward, 0);
        }
        if (wethAmt > 0) {
            uint rewardTokenAmt = 0;
            if (rewardToken != WETH) {
                rewardTokenAmt = QUOTER.quoteExactInputSingle(address(WETH), address(rewardToken), 3000, wethAmt, 0);
            } else {
                rewardTokenAmt = wethAmt;
            }
            rewardTokenAmt -= rewardTokenAmt * yieldFeePerc / 10000;
            accRewardPerlpToken_ += (rewardTokenAmt * 1e36 / getAllPool());
        }
        User storage user = userInfo[account];
        return (user.lpTokenBalance * accRewardPerlpToken_ / 1e36) - user.rewardStartAt;
    }

    function getUserBalance(address account) external view override returns (uint) {
        return userInfo[account].lpTokenBalance;
    }

    function getUserBalanceInUSD(address account) external view override returns (uint) {
        (, int latestPrice,,,) = ETH_USD_PRICE_ORACLE.latestRoundData();
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() * uint(latestPrice) / 1e26;
    }
}

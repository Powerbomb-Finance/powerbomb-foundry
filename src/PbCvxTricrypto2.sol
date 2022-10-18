// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./PbCvxBase.sol";
import "../interface/IChainlink.sol";
import "../interface/IWeth.sol";

contract PbCvxTricrypto2 is PbCvxBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant usdt = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IChainlink constant usdtUsdPriceOracle = IChainlink(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    IChainlink constant btcUsdPriceOracle = IChainlink(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
    IChainlink constant ethUsdPriceOracle = IChainlink(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    
    function initialize(uint _pid, IPool _pool, IERC20Upgradeable _rewardToken) external initializer {
        __Ownable_init();

        (address _lpToken,,, address _gauge) = booster.poolInfo(_pid);
        lpToken = IERC20Upgradeable(_lpToken);
        gauge = IGauge(_gauge);
        pid = _pid;
        pool = _pool;
        rewardToken = _rewardToken;
        treasury = msg.sender;

        (,,,,,,, address aTokenAddr,,,,) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        crv.approve(address(swapRouter), type(uint).max);
        cvx.approve(address(swapRouter), type(uint).max);
        usdt.safeApprove(address(pool), type(uint).max);
        wbtc.approve(address(pool), type(uint).max);
        weth.approve(address(pool), type(uint).max);
        lpToken.approve(address(pool), type(uint).max);
        lpToken.approve(address(booster), type(uint).max);
        rewardToken.approve(address(lendingPool), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override nonReentrant whenNotPaused {
        require(token == usdt || token == wbtc || token == weth || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        if (token == weth) {
            require(msg.value == amount, "Invalid ETH");
            IWeth(address(weth)).deposit{value: msg.value}();
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[3] memory amounts;
            if (token == usdt) amounts[0] = amount;
            else if (token == wbtc) amounts[1] = amount;
            else amounts[2] = amount; // token == weth
            pool.add_liquidity(amounts, amountOutMin);
            lpTokenAmt = lpToken.balanceOf(address(this));
        } else {
            lpTokenAmt = amount;
        }

        booster.deposit(pid, lpTokenAmt, true);

        User storage user = userInfo[msg.sender];
        user.lpTokenBalance += lpTokenAmt;
        user.rewardStartAt += (lpTokenAmt * accRewardPerlpToken / 1e36);

        emit Deposit(msg.sender, address(token), amount, lpTokenAmt);
    }

    function withdraw(
        IERC20Upgradeable token,
        uint lpTokenAmt,
        uint amountOutMin
    ) external payable override nonReentrant {
        require(token == usdt || token == wbtc || token == weth || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(lpTokenAmt > 0 && user.lpTokenBalance >= lpTokenAmt, "Invalid lpTokenAmt");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        harvest();

        user.lpTokenBalance = user.lpTokenBalance - lpTokenAmt;
        user.rewardStartAt = user.lpTokenBalance * accRewardPerlpToken / 1e36;
        gauge.withdrawAndUnwrap(lpTokenAmt, false);

        uint tokenAmt;
        if (token != lpToken) {
            uint i;
            if (token == usdt) i = 0;
            else if (token == wbtc) i = 1;
            else i = 2; // weth
            pool.remove_liquidity_one_coin(lpTokenAmt, i, amountOutMin);
            tokenAmt = token.balanceOf(address(this));
        } else {
            tokenAmt = lpTokenAmt;
        }

        if (token == weth) {
            IWeth(address(weth)).withdraw(tokenAmt);
            (bool success,) = msg.sender.call{value: tokenAmt}("");
            require(success, "ETH transfer failed");
        } else {
            token.safeTransfer(msg.sender, tokenAmt);
        }

        emit Withdraw(msg.sender, address(token), lpTokenAmt, tokenAmt);
    }

    receive() external payable {}

    function harvest() public override {
        // Update accrued amount of aToken
        uint allPool = getAllPool();
        uint aTokenAmt = aToken.balanceOf(address(this));
        if (aTokenAmt > lastATokenAmt) {
            uint accruedAmt = aTokenAmt - lastATokenAmt;
            accRewardPerlpToken += (accruedAmt * 1e36 / allPool);
            lastATokenAmt = aTokenAmt;
        }

        gauge.getReward(address(this), true); // true = including extra reward

        uint crvAmt = crv.balanceOf(address(this));
        uint cvxAmt = cvx.balanceOf(address(this));
        if (crvAmt > 1 ether || cvxAmt > 1 ether) {
            uint rewardTokenAmt;
            
            // Swap crv to rewardToken
            if (crvAmt > 1 ether) {
                ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: _getPath(crv),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: crvAmt,
                    amountOutMinimum: 0
                });
                rewardTokenAmt = swapRouter.exactInput(params);
                emit Harvest(address(crv), crvAmt, 0);
            }

            // Swap cvx to rewardToken
            if (cvxAmt > 1 ether) {
                ISwapRouter.ExactInputParams memory params = 
                    ISwapRouter.ExactInputParams({
                        path: _getPath(cvx),
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: cvxAmt,
                        amountOutMinimum: 0
                    });
                rewardTokenAmt += swapRouter.exactInput(params);
                emit Harvest(address(cvx), cvxAmt, 0);
            }

            // Calculate fee
            uint fee = rewardTokenAmt * yieldFeePerc / 10000;
            emit Harvest(address(rewardToken), rewardTokenAmt, fee);
            rewardTokenAmt -= fee;
            rewardToken.transfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (rewardTokenAmt * 1e36 / allPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.deposit(address(rewardToken), rewardTokenAmt, address(this), 0);

            // Update lastATokenAmt
            lastATokenAmt = aToken.balanceOf(address(this));

            // Update accumulate reward token amount
            accRewardTokenAmt += rewardTokenAmt;
        }
    }

    function claim() public override nonReentrant {
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
                rewardToken.transfer(msg.sender, rewardTokenAmt);

                emit Claim(msg.sender, rewardTokenAmt);
            }
        }
    }

    function _getPath(IERC20Upgradeable inputToken) private view returns (bytes memory path) {
        if (rewardToken != weth) {
            path = abi.encodePacked(
                address(inputToken),
                uint24(10000),
                address(weth),
                uint24(500),
                address(rewardToken)
            );
        } else {
            path = abi.encodePacked(
                address(inputToken),
                uint24(10000),
                address(weth)
            );
        }
    }

    ///@notice return 6 decimals
    function getPricePerFullShareInUSD() public view override returns (uint) {
        (, int usdtPriceInUsd,,,) = usdtUsdPriceOracle.latestRoundData();
        // pool.balances(0) is 6 decimals, uint(usdtPriceInUsd) is 8 decimals, convert result to 18 decimals by * 1e4
        uint totalUsdtInUsd = pool.balances(0) * uint(usdtPriceInUsd) * 1e4;
        (, int btcPriceInUsd,,,) = btcUsdPriceOracle.latestRoundData();
        // pool.balances(1) is 8 decimals, uint(btcPriceInUsd) is 8 decimals, convert result to 18 decimals by * 1e2
        uint totalWbtcInUsd = pool.balances(1) * uint(btcPriceInUsd) * 1e2;
        (, int ethPriceInUsd,,,) = ethUsdPriceOracle.latestRoundData();
        // pool.balances(2) is 18 decimals, uint(ethPriceInUsd) is 8 decimals, convert result to 18 decimals by / 1e18
        uint totalWethInUsd = pool.balances(2) * uint(ethPriceInUsd) / 1e8;
        uint totalAssetsInUsd = totalUsdtInUsd + totalWbtcInUsd + totalWethInUsd;
        return totalAssetsInUsd * 1e6 / lpToken.totalSupply();
    }

    ///@notice return 18 decimals
    function getAllPool() public view override returns (uint) {
        // convex lpToken, 18 decimals
        // 1 convex lpToken == 1 curve lpToken
        return gauge.balanceOf(address(this));
    }

    ///@notice return 6 decimals
    function getAllPoolInUSD() external view override returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function getPoolPendingReward() external view override returns (uint pendingCrv, uint pendingCvx) {
        pendingCrv = gauge.earned(address(this));
        // short calculation version of Convex.sol function mint()
        uint cliff = cvx.totalSupply() / 1e23;
        if (cliff < 1000) {
            uint reduction = 1000 - cliff;
            pendingCvx = pendingCrv * reduction / 1000;
        }
    }

    function getPoolExtraPendingReward() external view returns (uint) {
        return IGauge(gauge.extraRewards(0)).earned(address(this));
    }

    function getUserPendingReward(address account) external view override returns (uint) {
        User storage user = userInfo[account];
        return (user.lpTokenBalance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
    }

    ///@notice return 18 decimals
    function getUserBalance(address account) external view override returns (uint) {
        return userInfo[account].lpTokenBalance;
    }

    ///@notice return 6 decimals
    function getUserBalanceInUSD(address account) external view override returns (uint) {
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() / 1e18;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interface/IZap.sol";
import "./PbCvxBase.sol";

import "forge-std/console.sol";
contract PbCvxLusd is PbCvxBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant lusd = IERC20Upgradeable(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20Upgradeable constant lqty = IERC20Upgradeable(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    IPool constant threePool = IPool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    IZap constant zap = IZap(0xA79828DF1850E8a3A3064576f380D90aECDD3359);
    
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
        lqty.approve(address(swapRouter), type(uint).max);
        usdt.safeApprove(address(zap), type(uint).max);
        usdc.approve(address(zap), type(uint).max);
        dai.approve(address(zap), type(uint).max);
        lusd.approve(address(zap), type(uint).max);
        lpToken.approve(address(zap), type(uint).max);
        lpToken.approve(address(booster), type(uint).max);
        rewardToken.approve(address(lendingPool), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override nonReentrant whenNotPaused {
        require(token == lusd || token == usdt || token == usdc || token == dai || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[4] memory amounts;
            if (token == lusd) amounts[0] = amount;
            else if (token == dai) amounts[1] = amount;
            else if (token == usdc) amounts[2] = amount;
            else amounts[3] = amount; // token == usdt
            lpTokenAmt = zap.add_liquidity(address(pool), amounts, amountOutMin);
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
        require(token == lusd || token == usdt || token == usdc || token == dai || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(lpTokenAmt > 0 && user.lpTokenBalance >= lpTokenAmt, "Invalid lpTokenAmt");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        harvest();

        user.lpTokenBalance = user.lpTokenBalance - lpTokenAmt;
        user.rewardStartAt = user.lpTokenBalance * accRewardPerlpToken / 1e36;
        gauge.withdrawAndUnwrap(lpTokenAmt, false);

        uint tokenAmt;
        if (token != lpToken) {
            int128 i;
            if (token == lusd) i = 0;
            else if (token == dai) i = 1;
            else if (token == usdc) i = 2;
            else i = 3; // usdt
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

        gauge.getReward(address(this), true); // true = including extra reward

        uint crvAmt = crv.balanceOf(address(this));
        uint cvxAmt = cvx.balanceOf(address(this));
        uint lqtyAmt = lqty.balanceOf(address(this));
        if (crvAmt > 1 ether || cvxAmt > 1 ether || lqtyAmt > 1 ether) {
            uint rewardTokenAmt;
            
            // Swap crv to rewardToken
            if (crvAmt > 1 ether) {
                ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: _getPath(crv, 10000),
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
                        path: _getPath(cvx, 10000),
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: cvxAmt,
                        amountOutMinimum: 0
                    });
                rewardTokenAmt += swapRouter.exactInput(params);
                emit Harvest(address(cvx), cvxAmt, 0);
            }

            // Swap lqty to rewardToken
            if (lqtyAmt > 1 ether) {
                ISwapRouter.ExactInputParams memory params = 
                    ISwapRouter.ExactInputParams({
                        path: _getPath(lqty, 3000),
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: lqtyAmt,
                        amountOutMinimum: 0
                    });
                rewardTokenAmt += swapRouter.exactInput(params);
                emit Harvest(address(lqty), lqtyAmt, 0);
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

    function _getPath(IERC20Upgradeable inputToken, uint24 firstFee) private view returns (bytes memory path) {
        if (rewardToken != weth) {
            path = abi.encodePacked(
                address(inputToken),
                uint24(firstFee),
                address(weth),
                uint24(500),
                address(rewardToken)
            );
        } else {
            path = abi.encodePacked(
                address(inputToken),
                uint24(firstFee),
                address(weth)
            );
        }
    }

    ///@notice return 6 decimals
    function getPricePerFullShareInUSD() public view override returns (uint) {
        return pool.get_virtual_price() / 1e12;
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
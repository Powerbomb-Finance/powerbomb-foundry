// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interface/IChainlink.sol";
import "../interface/IRouter.sol";
import "./PbCvxBase.sol";

contract PbCvxCvxFxs is PbCvxBase {

    IERC20Upgradeable constant fxs = IERC20Upgradeable(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    IERC20Upgradeable constant cvxFxs = IERC20Upgradeable(0xFEEf77d3f69374f66429C91d732A244f074bdf74);
    IChainlink constant fxsUsdPriceOracle = IChainlink(0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f);
    IRouter constant router = IRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); // sushiswap
    
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
        fxs.approve(address(router), type(uint).max);
        fxs.approve(address(pool), type(uint).max);
        cvxFxs.approve(address(pool), type(uint).max);
        lpToken.approve(address(pool), type(uint).max);
        lpToken.approve(address(booster), type(uint).max);
        rewardToken.approve(address(lendingPool), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override nonReentrant whenNotPaused {
        require(token == fxs || token == cvxFxs || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.transferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[2] memory amounts;
            if (token == fxs) amounts[0] = amount;
            else amounts[1] = amount; // token == cvxFxs
            lpTokenAmt = pool.add_liquidity(amounts, amountOutMin);
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
        require(token == fxs || token == cvxFxs || token == lpToken, "Invalid token");
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
            if (token == fxs) i = 0;
            else i = 1; // cvxFxs
            tokenAmt = pool.remove_liquidity_one_coin(lpTokenAmt, i, amountOutMin, false);
        } else {
            tokenAmt = lpTokenAmt;
        }
       
        token.transfer(msg.sender, tokenAmt);

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

        uint crvAmt = crv.balanceOf(address(this));
        uint cvxAmt = cvx.balanceOf(address(this));
        uint fxsAmt = fxs.balanceOf(address(this));
        if (crvAmt > 1 ether || cvxAmt > 1 ether || fxsAmt > 0.5 ether ) {
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

            // Swap fxs to rewardToken
            if (fxsAmt > 0.5 ether) {
                uint index = rewardToken ==  weth ? 2 : 3;
                address[] memory path = new address[](index);
                path[0] = address(fxs);
                path[1] = address(weth);
                if (rewardToken != weth) path[2] = address(rewardToken);
                rewardTokenAmt += router.swapExactTokensForTokens(
                    fxsAmt,
                    0,
                    path,
                    address(this),
                    block.timestamp
                )[index - 1];
                emit Harvest(address(fxs), fxsAmt, 0);
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
        // get fxs per cvxFxs
        uint fxsPerCvxCrv = pool.get_dy(uint(1), uint(0), 1 ether);
        // get total cvxFxs in fxs
        uint totalCvxFxsInCrv = pool.balances(1) * fxsPerCvxCrv / 1e18;
        // get total fxs
        uint totalFxs = pool.balances(0);
        // get total pool in fxs
        uint totalPoolInFxs = totalCvxFxsInCrv + totalFxs;
        // get pricePerFullShareInFxs
        uint pricePerFullShareInFxs = totalPoolInFxs * 1e18 / lpToken.totalSupply();
        // get fxs price in usd
        (, int latestPrice,,,) = fxsUsdPriceOracle.latestRoundData(); // return 8 decimals
        
        return pricePerFullShareInFxs * uint(latestPrice) / 1e20;
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

    function getPoolExtraPendingReward(uint index) external view returns (uint) {
        return IGauge(gauge.extraRewards(index)).earned(address(this));
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
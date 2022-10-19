// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./PbAuraBase.sol";
import "../interface/IPool.sol";

contract PbAuraStable is PbAuraBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant usdt = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Upgradeable constant dai = IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Upgradeable constant bbaUsdt = IERC20Upgradeable(0x2F4eb100552ef93840d5aDC30560E5513DFfFACb); // bb-a-usdt balancer
    bytes32 constant bbaUsdtPoolId = 0x2f4eb100552ef93840d5adc30560e5513dfffacb000000000000000000000334;
    IERC20Upgradeable constant bbaUsdc = IERC20Upgradeable(0x82698aeCc9E28e9Bb27608Bd52cF57f704BD1B83); // bb-a-usdc balancer
    bytes32 constant bbaUsdcPoolId = 0x82698aecc9e28e9bb27608bd52cf57f704bd1b83000000000000000000000336;
    IERC20Upgradeable constant bbaDai = IERC20Upgradeable(0xae37D54Ae477268B9997d4161B96b8200755935c); // bb-a-dai balancer
    bytes32 constant bbaDaiPoolId = 0xae37d54ae477268b9997d4161b96b8200755935c000000000000000000000337;
    IERC20Upgradeable constant bbaUsd = IERC20Upgradeable(0xA13a9247ea42D743238089903570127DdA72fE44); // bb-a-usd balancer, same as lpToken
    bytes32 constant bbaUsdPoolId = 0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d;
    
    function initialize(uint _pid, IERC20Upgradeable _rewardToken) external initializer {
        __Ownable_init();

        (address _lpToken,,, address _gauge) = booster.poolInfo(_pid);
        lpToken = IERC20Upgradeable(_lpToken);
        gauge = IGauge(_gauge);
        pid = _pid;
        rewardToken = _rewardToken;
        treasury = msg.sender;

        (,,,,,,, address aTokenAddr,,,,) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        bal.approve(address(balancer), type(uint).max);
        aura.approve(address(balancer), type(uint).max);
        weth.approve(address(balancer), type(uint).max);
        usdt.safeApprove(address(balancer), type(uint).max);
        usdc.approve(address(balancer), type(uint).max);
        dai.approve(address(balancer), type(uint).max);
        lpToken.approve(address(booster), type(uint).max);
        lpToken.approve(address(balancer), type(uint).max);
        rewardToken.approve(address(lendingPool), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override nonReentrant whenNotPaused {
        require(token == usdt || token == usdc || token == dai || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            // zap swap from stablecoin to lp token
            lpTokenAmt = _zapSwap(token, amount, amountOutMin, true);
        } else { // token == lpToken
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
        require(token == usdt || token == usdc || token == dai || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(lpTokenAmt > 0 && user.lpTokenBalance >= lpTokenAmt, "Invalid lpTokenAmt");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        harvest();

        user.lpTokenBalance = user.lpTokenBalance - lpTokenAmt;
        user.rewardStartAt = user.lpTokenBalance * accRewardPerlpToken / 1e36;
        gauge.withdrawAndUnwrap(lpTokenAmt, false);

        uint tokenAmt;
        if (token != lpToken) {
            // zap swap from lp token to stablecoin
            tokenAmt = _zapSwap(token, lpTokenAmt, amountOutMin, false);
        } else { // token == lpToken
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

        uint balAmt = bal.balanceOf(address(this));
        uint auraAmt = aura.balanceOf(address(this));
        if (balAmt > 1 ether || auraAmt > 1 ether) {
            uint wethAmt;
            
            // Swap bal to weth
            if (balAmt > 1 ether) {
                wethAmt = _swap(
                    0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014, // bal-weth poolId
                    address(bal),
                    address(weth),
                    balAmt
                );

                emit Harvest(address(bal), balAmt, 0);
            }

            // Swap aura to weth
            if (auraAmt > 1 ether) {
                wethAmt += _swap(
                    0xc29562b045d80fd77c69bec09541f5c16fe20d9d000200000000000000000251, // aura-weth poolId
                    address(aura),
                    address(weth),
                    auraAmt
                );

                emit Harvest(address(aura), auraAmt, 0);
            }

            uint rewardTokenAmt;
            if (rewardToken != weth) {
                // Swap weth to reward token
                rewardTokenAmt = _swap(
                    0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e, // weth-wbtc
                    address(weth),
                    address(rewardToken),
                    wethAmt
                );

            } else {
                rewardTokenAmt = wethAmt;
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

    function _zapSwap(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        bool _deposit
    ) private returns (uint amountOut) {
        bytes32 poolId;
        IERC20Upgradeable bbaToken;
        if (token == usdt) {
            poolId = bbaUsdtPoolId; // usdt-aUsdt-bbaUsdt
            bbaToken = bbaUsdt;
        } else if (token == usdc) {
            poolId = bbaUsdcPoolId; // usdc-aUsdc-bbaUsdc
            bbaToken = bbaUsdc;
        } else { // token == dai
            poolId = bbaDaiPoolId; // dai-aDai-bbaDai
            bbaToken = bbaDai;
        }

        address[] memory assets = new address[](3);
        assets[1] = address(bbaToken);
        bytes32 poolId0;
        bytes32 poolId1;
        if (_deposit) {
            // stablecoin -> bbaToken -> bbaUsd(lpToken)
            assets[0] = address(token);
            assets[2] = address(bbaUsd);
            poolId0 = poolId;
            poolId1 = bbaUsdPoolId;
        } else { // withdraw
            // bbaUsd(lpToken) -> bbaToken -> stablecoin
            assets[0] = address(bbaUsd);
            assets[2] = address(token);
            poolId0 = bbaUsdPoolId;
            poolId1 = poolId;
        }

        IBalancer.BatchSwapStep[] memory swaps = new IBalancer.BatchSwapStep[](2);
        swaps[0] = IBalancer.BatchSwapStep({
            poolId: poolId0,
            assetInIndex: 0, // asset in out index follow assets above
            assetOutIndex: 1,
            amount: amount,
            userData: ""
        });
        swaps[1] = IBalancer.BatchSwapStep({
            poolId: poolId1,
            assetInIndex: 1,
            assetOutIndex: 2,
            amount: 0,
            userData: ""
        });

        IBalancer.FundManagement memory funds = IBalancer.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this),
            toInternalBalance: false
        });

        int[] memory limits = new int[](3);
        limits[0] = int(amount); // token into balancer vault = positive
        limits[2] = -int(amountOutMin); // token out from balancer vault = negative

        int[] memory assetDeltas = balancer.batchSwap(
            IBalancer.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds,
            limits,
            block.timestamp
        );
        amountOut = uint(-assetDeltas[2]); // make positive & uint
    }

    function _swap(bytes32 _poolId, address tokenIn, address tokenOut, uint amount) private returns (uint amountOut) {
        IBalancer.SingleSwap memory singleSwap = IBalancer.SingleSwap({
            poolId: _poolId,
            kind: IBalancer.SwapKind.GIVEN_IN,
            assetIn: tokenIn,
            assetOut: tokenOut,
            amount: amount,
            userData: ""
        });
        IBalancer.FundManagement memory funds = IBalancer.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this),
            toInternalBalance: false
        });
        amountOut = balancer.swap(singleSwap, funds, 0, block.timestamp);
    }

    function getPricePerFullShareInUSD() public view override returns (uint) {
        return IPool(address(lpToken)).getRate();
    }

    ///@notice return 18 decimals
    function getAllPool() public view override returns (uint) {
        // gauge.balanceOf return aura lpToken amount, 18 decimals
        // 1 aura lpToken == 1 bal lpToken (bpt)
        return gauge.balanceOf(address(this));
    }

    ///@notice return 6 decimals
    function getAllPoolInUSD() external view override returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18;
    }

    function getPoolPendingReward() external view override returns (uint pendingBal, uint pendingAura) {
        pendingBal = gauge.earned(address(this));

        // short calculation version of Aura.sol function mint()
        uint cliff = (aura.totalSupply() - 5e25) / 1e23;
        if (cliff < 500) {
            uint reduction = (500 - cliff) * 5 / 2 + 700;
            pendingAura = pendingBal * reduction / 500;
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
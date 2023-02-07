// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./PbCrvBase.sol";
import "../interface/IRouter.sol";
import "../interface/IMinter.sol";
import "../interface/IChainlink.sol";

contract PbCrvPolyTri is PbCrvBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant DAI = IERC20Upgradeable(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20Upgradeable constant USDT = IERC20Upgradeable(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    IChainlink constant BTCPriceOracle = IChainlink(0xc907E116054Ad103354f2D350FD2514433D57F6f);
    IChainlink constant ETHPriceOracle = IChainlink(0xF9680D99D6C9589e2a93a78A04A279e509205945);
    IRouter constant router = IRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IMinter constant minter = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);

    function initialize(IERC20Upgradeable _rewardToken, address _treasury) external initializer {
        __Ownable_init();

        CRV = IERC20Upgradeable(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
        lpToken = IERC20Upgradeable(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
        rewardToken = _rewardToken;
        pool = IPool(0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8); // zap contract
        gauge = IGauge(0xBb1B19495B8FE7C402427479B9aC14886cbbaaeE);
        treasury = _treasury;
        yieldFeePerc = 500;
        lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        DAI.safeApprove(address(pool), type(uint).max);
        USDC.safeApprove(address(pool), type(uint).max);
        USDT.safeApprove(address(pool), type(uint).max);
        WBTC.safeApprove(address(pool), type(uint).max);
        WETH.safeApprove(address(pool), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        lpToken.safeApprove(address(pool), type(uint).max);
        CRV.safeApprove(address(router), type(uint).max);
        rewardToken.safeApprove(address(lendingPool), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable override nonReentrant whenNotPaused {
        require(token == DAI|| token == USDC || token == USDT || token == WBTC || token == WETH || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = gauge.balanceOf(address(this));
        if (currentPool > 0) harvest();

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            uint[5] memory amounts;
            if (token == DAI) amounts[0] = amount;
            else if (token == USDC) amounts[1] = amount;
            else if (token == USDT) amounts[2] = amount;
            else if (token == WBTC) amounts[3] = amount;
            else amounts[4] = amount; // token == WETH
            pool.add_liquidity(amounts, amountOutMin);
            lpTokenAmt = lpToken.balanceOf(address(this));
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
        require(token == DAI|| token == USDC || token == USDT || token == WBTC || token == WETH || token == lpToken, "Invalid token");
        User storage user = userInfo[msg.sender];
        require(lpTokenAmt > 0 && user.lpTokenBalance >= lpTokenAmt, "Invalid lpTokenAmt to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        claim();

        user.lpTokenBalance = user.lpTokenBalance - lpTokenAmt;
        user.rewardStartAt = user.lpTokenBalance * accRewardPerlpToken / 1e36;
        gauge.withdraw(lpTokenAmt);

        uint tokenAmt;
        if (token != lpToken) {
            uint i;
            if (token == DAI) i = 0;
            else if (token == USDC) i = 1;
            else if (token == USDT) i = 2;
            else if (token == WBTC) i = 3;
            else i = 4; // WETH
            pool.remove_liquidity_one_coin(lpTokenAmt, i, amountOutMin);
            tokenAmt = token.balanceOf(address(this));
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

        // gauge.claim_rewards();
        minter.mint(address(gauge));

        uint CRVAmt = CRV.balanceOf(address(this));
        if (CRVAmt > 1e18) {
            uint rewardTokenAmt;
            if (rewardToken == WETH) {
                address[] memory path = new address[](2);
                path[0] = address(CRV);
                path[1] = address(WETH);
                rewardTokenAmt = router.swapExactTokensForTokens(
                    CRVAmt,
                    0,
                    path,
                    address(this),
                    block.timestamp
                )[1];
            } else {
                rewardTokenAmt = _swap(rewardToken, CRVAmt);
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

    function _swap(IERC20Upgradeable _rewardToken, uint amount) private returns (uint) {
        address[] memory path = new address[](3);
        path[0] = address(CRV);
        path[1] = address(WETH);
        path[2] = address(_rewardToken);
        return router.swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        )[2];
    }

    function getPricePerFullShareInUSD() public view override returns (uint) {
        // Get total USD for each asset (18 decimals)
        IPool realPool = IPool(pool.pool()); // global variable pool is actually zap contract
        uint total3CRVInUSD = realPool.balances(0) * IPool(pool.base_pool()).get_virtual_price() / 1e18;
        // Get BTC price from Chainlink
        (, int BTCPrice,,,) = BTCPriceOracle.latestRoundData();
        // realPool.balances(1) is 8 decimals, uint(BTCPrice) is 8 decimals, make result 18 decimals by * 1e2
        uint totalWBTCInUSD = realPool.balances(1) * uint(BTCPrice) * 1e2;
        // Get ETH price from Chainlink
        (, int ETHPrice,,,) = ETHPriceOracle.latestRoundData();
        // realPool.balances(2) is 18 decimals, uint(ETHPrice) is 8 decimals, make result 18 decimals by / 1e18
        uint totalWETHInUSD = realPool.balances(2) * uint(ETHPrice) / 1e8;
        uint totalAssetsInUSD = total3CRVInUSD + totalWBTCInUSD + totalWETHInUSD;
        // Calculate price per full share
        return totalAssetsInUSD * 1e6 / lpToken.totalSupply(); // 6 decimals
    }

    function getAllPool() public view override returns (uint) {
        return gauge.balanceOf(address(this)); // lpToken, 18 decimals
    }

    function getAllPoolInUSD() external view override returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function getPoolPendingReward() external override returns (uint) {
        return gauge.claimable_tokens(address(this));
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

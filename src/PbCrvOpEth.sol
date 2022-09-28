// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PbCrvBase.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IZap.sol";
import "../interface/IMinter.sol";
import "../interface/IRewardsController.sol";
import "../interface/IChainlink.sol";

contract PbCrvOpEth is PbCrvBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant SETH = IERC20Upgradeable(0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IMinter constant minter = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    IRewardsController constant rewardsController = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
    IChainlink constant ethUsdPriceOracle = IChainlink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function initialize(IERC20Upgradeable _rewardToken, address _treasury) external initializer {
        __Ownable_init();

        CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
        lpToken = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
        rewardToken = _rewardToken;
        pool = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
        gauge = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
        treasury = _treasury;
        yieldFeePerc = 500;
        lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(rewardToken));
        aToken = IERC20Upgradeable(aTokenAddr);

        SETH.safeApprove(address(pool), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        lpToken.safeApprove(address(pool), type(uint).max);
        CRV.safeApprove(address(swapRouter), type(uint).max);
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
        minter.mint(address(gauge)); // to claim crv
        gauge.claim_rewards(); // to claim op

        // Claim OP from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        rewardsController.claimRewards(assets, type(uint).max, address(this), address(OP));

        uint CRVAmt = CRV.balanceOf(address(this));
        uint OPAmt = OP.balanceOf(address(this));
        if (CRVAmt > 1 ether || OPAmt > 1 ether) {
            uint rewardTokenAmt;
            
            // Swap CRV to rewardToken
            if (CRVAmt > 1 ether) {
                ISwapRouter.ExactInputParams memory params = 
                    ISwapRouter.ExactInputParams({
                        path: abi.encodePacked(address(CRV), uint24(3000), address(WETH), uint24(500), address(USDC)),
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: CRVAmt,
                        amountOutMinimum: 0
                    });
                rewardTokenAmt = swapRouter.exactInput(params);
            }

            // Swap OP to rewardToken
            if (OPAmt > 1 ether) {
                rewardTokenAmt += swapRouter.exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(OP),
                        tokenOut: address(USDC),
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: OPAmt,
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
        (, int latestPrice,,,) = ethUsdPriceOracle.latestRoundData();
        return allPool * getPricePerFullShareInUSD() * uint(latestPrice) / 1e26; // 6 decimals
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
        (, int latestPrice,,,) = ethUsdPriceOracle.latestRoundData();
        return userInfo[account].lpTokenBalance * getPricePerFullShareInUSD() * uint(latestPrice) / 1e26;
    }
}

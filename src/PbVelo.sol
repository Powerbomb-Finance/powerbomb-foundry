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
import "../interfaces/IRewardsController.sol";

contract PbVelo is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;
    using SafeERC20Upgradeable for IPair;

    IERC20Upgradeable constant VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IRouter constant router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IChainLink constant WETHPriceFeed = IChainLink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    ILendingPool constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IRewardsController constant rewardsController = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
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
    uint public swapThreshold;
    uint public accRewardTokenAmt;

    event Deposit(address indexed tokenDeposit, uint amountToken, uint amountlpToken);
    event Withdraw(address indexed tokenWithdraw, uint amountToken);
    event Harvest(uint harvestedfarmToken, uint swappedRewardTokenAfterFee, uint fee);
    event Claim(address receiver, uint claimedATokenAmt, uint claimedRewardTokenAmt);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);
    event SetSwapThreshold(uint oldSwapThreshold, uint newSwapThreshold);

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
        if (OP.allowance(address(this), address(router)) == 0) {
            OP.safeApprove(address(router), type(uint).max);
        }
    }

    function deposit(
        IERC20Upgradeable token, uint amount, uint swapPerc, uint amountOutMin
    ) external payable virtual nonReentrant whenNotPaused {
        require(token == token0 || token == token1 || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        // harvest before new deposit
        uint currentPool = getAllPool();
        if (currentPool > 0) harvest();

        // record for calculate leftover
        uint token0AmtBef = token0.balanceOf(address(this));
        uint token1AmtBef = token1.balanceOf(address(this));

        if (msg.value != 0) {
            // eth deposit, wrap into weth
            require(token == WETH, "WETH only for ETH deposit");
            require(amount == msg.value, "Invalid ETH amount");
            WETH.deposit{value: msg.value}();
        } else {
            // normal token deposit
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
        // record this to prevent deposit & withdraw in 1 tx
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            (uint amountA, uint amountB) = (0, 0);
            if (token == token0) {
                // swap token0 to token1 based on swapPerc
                amountA = amount * swapPerc / 1000;
                amountB = swap(address(token0), address(token1), stable, amountA, amountOutMin);
                amountA = amount - amountA;
            } else {
                // swap token1 to token0 based on swapPerc
                amountB = amount * swapPerc / 1000;
                amountA = swap(address(token1), address(token0), stable, amountB, amountOutMin);
                amountB = amount - amountB;
            }
            // add liquidity
            (,, lpTokenAmt) = router.addLiquidity(
                address(token0), address(token1), stable, amountA, amountB, 0, 0, address(this), block.timestamp
            );

            // check if any leftover
            {
                uint token0AmtLeft = token0.balanceOf(address(this)) - token0AmtBef;
                uint token1AmtLeft = token1.balanceOf(address(this)) - token1AmtBef;
                if (token0AmtLeft > 0) {
                    if (stable) {
                        if (token0 == USDC || token1 == USDC) {
                            if (token0AmtLeft > 10 * 10 ** uint(IERC20MetadataUpgradeable(address(token0)).decimals())) {
                                // leftover for token0 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token0AmtLeft, token0, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token0.safeTransfer(msg.sender, token0AmtLeft);
                            }

                        } else if (token0 == WETH || token1 == WETH) {
                            (uint usdcAmt,) = router.getAmountOut(token0AmtLeft, address(WETH), address(USDC));
                            if (usdcAmt > 10e6) {
                                // leftover for token0 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token0AmtLeft, token0, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token0.safeTransfer(msg.sender, token0AmtLeft);
                            }

                        } else {
                            // not pair with usdc or weth, just return leftover to msg.sender
                            token0.safeTransfer(msg.sender, token0AmtLeft);
                        }

                    } else { // not stable pair
                        if (token0 == USDC) {
                            if (token0AmtLeft > 10e6) {
                                // leftover for USDC > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token0AmtLeft, USDC, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                USDC.safeTransfer(msg.sender, token0AmtLeft);
                            }

                        } else if (token1 == USDC) {
                            (uint usdcAmt,) = router.getAmountOut(token0AmtLeft, address(token0), address(USDC));
                            if (usdcAmt > 10e6) {
                                // leftover for token0 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token0AmtLeft, token0, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token0.safeTransfer(msg.sender, token0AmtLeft);
                            }

                        } else {
                            // not pair with usdc, just return leftover to msg.sender
                            token0.safeTransfer(msg.sender, token0AmtLeft);
                        }
                    }
                }

                if (token1AmtLeft > 0) {
                    if (stable) {
                        if (token0 == USDC || token1 == USDC) {
                            if (token1AmtLeft > 10 * 10 ** uint(IERC20MetadataUpgradeable(address(token1)).decimals())) {
                                // leftover for token1 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token1AmtLeft, token1, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token1.safeTransfer(msg.sender, token1AmtLeft);
                            }

                        } else if (token0 == WETH || token1 == WETH) {
                            (uint usdcAmt,) = router.getAmountOut(token1AmtLeft, address(WETH), address(USDC));
                            if (usdcAmt > 10e6) {
                                // leftover for token1 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token1AmtLeft, token1, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token1.safeTransfer(msg.sender, token1AmtLeft);
                            }

                        } else {
                            // not pair with usdc or weth, just return leftover to msg.sender
                            token1.safeTransfer(msg.sender, token1AmtLeft);
                        }

                    } else { // not stable pair
                        if (token0 == USDC) {
                            (uint usdcAmt,) = router.getAmountOut(token1AmtLeft, address(token1), address(USDC));
                            if (usdcAmt > 10e6) {
                                // leftover for token0 > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token1AmtLeft, token1, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                token1.safeTransfer(msg.sender, token0AmtLeft);
                            }

                        } else if (token1 == USDC) {
                            if (token1AmtLeft > 10e6) {
                                // leftover for USDC > 10 USD, redo swap & add liquidity
                                lpTokenAmt += _reAddLiquidity(token1AmtLeft, USDC, token0AmtBef, token1AmtBef);

                            } else {
                                // leftover < 10 USD, return to msg.sender
                                USDC.safeTransfer(msg.sender, token1AmtLeft);
                            }

                        } else {
                            // not pair with usdc, just return leftover to msg.sender
                            token0.safeTransfer(msg.sender, token1AmtLeft);
                        }
                    }
                }
            }

        } else {
            // deposit lp token
            lpTokenAmt = amount;
        }

        // deposit lp token into gauge
        gauge.deposit(lpTokenAmt, 0);
        // record user state
        User storage user = userInfo[msg.sender];
        user.lpTokenBalance += lpTokenAmt;
        user.rewardStartAt += (lpTokenAmt * reward.accRewardPerlpToken / 1e36);

        emit Deposit(address(token), amount, lpTokenAmt);
    }

    function _reAddLiquidity(
        uint amount,
        IERC20Upgradeable tokenIn,
        uint token0AmtBef,
        uint token1AmtBef
    ) private returns (uint) {
        IERC20Upgradeable tokenOut = tokenIn == token0 ? token1 : token0;
        uint amountIn = amount / 2;
        uint amountOut = swap(address(tokenIn), address(tokenOut), stable, amountIn, 0);
        (,, uint lpTokenAmt) = router.addLiquidity(
            address(tokenIn), address(tokenOut), stable, amountIn, amountOut, 0, 0, address(this), block.timestamp
        );

        // check leftover again and return to msg.sender if any
        uint token0AmtLeft_ = token0.balanceOf(address(this)) - token0AmtBef;
        if (token0AmtLeft_ > 0) token0.safeTransfer(msg.sender, token0AmtLeft_);
        uint token1AmtLeft_ = token1.balanceOf(address(this)) - token1AmtBef;
        if (token1AmtLeft_ > 0) token1.safeTransfer(msg.sender, token1AmtLeft_);

        return lpTokenAmt;
    }

    function withdraw(
        IERC20Upgradeable token, uint amountOutLpToken, uint amountOutMin
    ) external virtual nonReentrant returns (uint amountOutToken) {
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

        if (token == WETH) {
            WETH.withdraw(WETH.balanceOf(address(this)));
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        } else {
            token.safeTransfer(msg.sender, amountOutToken);
        }

        emit Withdraw(address(token), amountOutToken);
    }

    receive() external payable {}

    function harvest() public virtual {
        uint currentPool = getAllPool();

        // Update accrued amount of aToken
        uint aTokenAmt = reward.aToken.balanceOf(address(this));
        if (aTokenAmt > reward.lastATokenAmt) {
            uint accruedAmt = aTokenAmt - reward.lastATokenAmt;
            reward.accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
            reward.lastATokenAmt = aTokenAmt;
        }

        // Collect VELO & OP from gauge
        address[] memory tokens = new address[](2);
        tokens[0] = address(VELO);
        tokens[1] = address(OP);
        gauge.getReward(address(this), tokens);

        // Claim OP from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(reward.aToken);
        rewardsController.claimRewards(assets, type(uint).max, address(this), address(OP));

        // Calculate WETH amount of VELO
        uint VELOAmt = VELO.balanceOf(address(this));
        uint WETHAmt = getAmountOut(VELOAmt, address(VELO), address(WETH));

        // Calculate WETH amount of OP
        uint OPAmt = OP.balanceOf(address(this));
        WETHAmt += getAmountOut(OPAmt, address(OP), address(WETH));

        if (WETHAmt > swapThreshold) {
            WETHAmt = 0;
            // Swap VELO to WETH
            if (VELOAmt > 1 ether) {
                WETHAmt = swap(address(VELO), address(WETH), false, VELOAmt, 0);
            }

            // Swap OP to WETH
            if (reward.rewardToken != USDC) {
                // If reward.rewardtoken == USDC, swap OP directly to USDC below
                if (OPAmt > 1 ether) {
                    WETHAmt += swap(address(OP), address(WETH), false, OPAmt, 0);
                }
            }

            // Swap WETH to reward token
            uint rewardTokenAmt = 0;
            if (reward.rewardToken == WBTC) {
                if (WETHAmt > 0) {
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
                }

            } else if (reward.rewardToken == USDC) {
                if (WETHAmt > 0) {
                    rewardTokenAmt = swap(address(WETH), address(reward.rewardToken), false, WETHAmt, 0);
                }
                if (OPAmt > 1 ether) {
                    rewardTokenAmt += swap(address(OP), address(reward.rewardToken), false, OPAmt, 0);
                }

            } else { // reward.rewardToken == WETH
                rewardTokenAmt = WETHAmt;
            }

            uint fee = 0;
            if (rewardTokenAmt > 0) {
                // Calculate fee
                fee = rewardTokenAmt * yieldFeePerc / 10000;
                rewardTokenAmt -= fee;
                reward.rewardToken.safeTransfer(treasury, fee);

                // Update accRewardPerlpToken
                reward.accRewardPerlpToken += (rewardTokenAmt * 1e36 / currentPool);

                // Deposit reward token into Aave to get interest bearing aToken
                lendingPool.supply(address(reward.rewardToken), rewardTokenAmt, address(this), 0);

                // Update lastATokenAmt
                reward.lastATokenAmt = reward.aToken.balanceOf(address(this));

                accRewardTokenAmt += rewardTokenAmt;
            }

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
        if (amount == 0) return 0;

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

            IRouter.route[] memory routes = new IRouter.route[](2);
            uint token0PriceInETH;
            uint token1PriceInETH;
            if (token0 == USDC && stable == true) {
                (token0PriceInETH,) = router.getAmountOut(1e6, address(USDC), address(WETH));
                routes[0] = IRouter.route({
                    from: address(token1),
                    to: address(USDC),
                    stable: true
                });
                routes[1] = IRouter.route({
                    from: address(USDC),
                    to: address(WETH),
                    stable: false
                });
                token1PriceInETH = router.getAmountsOut(10 ** token1Decimals, routes)[2];
            } else if (token1 == USDC && stable == true) {
                routes[0] = IRouter.route({
                    from: address(token0),
                    to: address(USDC),
                    stable: false
                });
                routes[1] = IRouter.route({
                    from: address(USDC),
                    to: address(WETH),
                    stable: false
                });
                token0PriceInETH = router.getAmountsOut(10 ** token0Decimals, routes)[2];
                (token1PriceInETH,) = router.getAmountOut(1e6, address(USDC), address(WETH));
            } else {
                (token0PriceInETH,) = router.getAmountOut(10 ** token0Decimals, address(token0), address(WETH));
                (token1PriceInETH,) = router.getAmountOut(10 ** token1Decimals, address(token1), address(WETH));
            }

            uint reserveToken0InETH = reserveToken0 * token0PriceInETH / 10 ** token0Decimals;
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

    function setSwapThreshold(uint _swapThreshold) external onlyOwner {
        emit SetSwapThreshold(swapThreshold, _swapThreshold);
        swapThreshold = _swapThreshold;
    }

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) internal view returns (uint amountOut) {
        if (amountIn > 0) {
            (amountOut,) = router.getAmountOut(amountIn, tokenIn, tokenOut);
        } else {
            amountOut = 0;
        }
    }

    function getPricePerFullShareInUSD() public view virtual returns (uint) {
        (, int rawPrice,,,) = WETHPriceFeed.latestRoundData();

        return getLpTokenPriceInETH() * uint(rawPrice) / 1e20; // 6 decimals
    }

    function getAllPool() public view returns (uint) {
        return gauge.balanceOf(address(this));
    }

    function getAllPoolInUSD() external view returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    function getPoolPendingReward() external view returns (uint) {
        return gauge.earned(address(VELO), address(this)) + VELO.balanceOf(address(this));
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
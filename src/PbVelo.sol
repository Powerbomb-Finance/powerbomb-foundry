// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from 
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IPair} from "../interfaces/IPair.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {IGauge} from "../interfaces/IGauge.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IChainLink} from "../interfaces/IChainLink.sol";
import {IRewardsController} from "../interfaces/IRewardsController.sol";

contract PbVelo is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;
    using SafeERC20Upgradeable for IPair;

    IERC20Upgradeable private constant VELO = IERC20Upgradeable(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    IRouter private constant ROUTER = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    IERC20Upgradeable private constant WBTC = IERC20Upgradeable(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    IWETH private constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable private constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable private constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IChainLink private constant WETH_PRICE_FEED = IChainLink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    ILendingPool private constant LENDING_POOL = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IRewardsController private constant REWARDS_CONTROLLER = 
        IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
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
        IGauge gauge_,
        IERC20Upgradeable rewardToken_,
        address treasury_,
        uint swapThreshold_
    ) external virtual initializer {
        require(treasury_ != address(0), "address 0");
        __Ownable_init();

        gauge = gauge_;
        address lpToken_ = gauge.stake();
        lpToken = IPair(lpToken_);
        (address token0_, address token1_) = lpToken.tokens();
        token0 = IERC20Upgradeable(token0_);
        token1 = IERC20Upgradeable(token1_);
        stable = lpToken.stable();
        reward.rewardToken = rewardToken_;
        (,,,,,,,,address _aTokenAddr) = LENDING_POOL.getReserveData(address(rewardToken_));
        reward.aToken = IERC20Upgradeable(_aTokenAddr);
        treasury = treasury_;
        swapThreshold = swapThreshold_;
        yieldFeePerc = 50; // 2 decimals, 50 = 0.5%

        token0.safeApprove(address(ROUTER), type(uint).max);
        token1.safeApprove(address(ROUTER), type(uint).max);
        lpToken.safeApprove(address(ROUTER), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        VELO.safeApprove(address(ROUTER), type(uint).max);
        reward.rewardToken.safeApprove(address(LENDING_POOL), type(uint).max);

        if (WETH.allowance(address(this), address(ROUTER)) == 0) {
            WETH.safeApprove(address(ROUTER), type(uint).max);
        }
        if (OP.allowance(address(this), address(ROUTER)) == 0) {
            OP.safeApprove(address(ROUTER), type(uint).max);
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

        _tokenTransferOrWrapEth(token, amount);
        
        // record this to prevent deposit & withdraw in 1 tx
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            (uint amountA, uint amountB) = _swapTokenBasedOnSwapPerc(token, amount, amountOutMin, swapPerc);

            // add liquidity
            (,, lpTokenAmt) = ROUTER.addLiquidity(
                address(token0), address(token1), stable, amountA, amountB, 0, 0, address(this), block.timestamp
            );

            // check if any leftover
            {
                uint token0AmtLeft = token0.balanceOf(address(this)) - token0AmtBef;
                uint token1AmtLeft = token1.balanceOf(address(this)) - token1AmtBef;
                if (token0AmtLeft > 0) {
                    lpTokenAmt += _reAddLiquidityOrTransferBack(
                        token0,
                        token0AmtLeft,
                        token0AmtBef,
                        token1AmtBef
                    );
                }

                if (token1AmtLeft > 0) {
                    lpTokenAmt += _reAddLiquidityOrTransferBack(
                        token1,
                        token1AmtLeft,
                        token0AmtBef,
                        token1AmtBef
                    );
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

    function _tokenTransferOrWrapEth(IERC20Upgradeable token, uint amount) private {
        if (msg.value != 0) {
            // eth deposit, wrap into weth
            require(token == WETH, "WETH only for ETH deposit");
            require(amount == msg.value, "Invalid ETH amount");
            WETH.deposit{value: msg.value}();
        } else {
            // normal token deposit
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _swapTokenBasedOnSwapPerc(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        uint swapPerc
    ) private returns (uint amountA, uint amountB) {
        if (token == token0) {
            // swap token0 to token1 based on swapPerc
            amountA = amount * swapPerc / 1000;
            amountB = _swap(address(token0), address(token1), stable, amountA, amountOutMin);
            amountA = amount - amountA;
        } else {
            // swap token1 to token0 based on swapPerc
            amountB = amount * swapPerc / 1000;
            amountA = _swap(address(token1), address(token0), stable, amountB, amountOutMin);
            amountB = amount - amountB;
        }
    }

    function _reAddLiquidityOrTransferBack(
        IERC20Upgradeable tokenWithAmtLeft,
        uint amtLeft,
        uint token0AmtBef,
        uint token1AmtBef
    ) private returns (uint extraLpTokenAmt) {
        if (stable) {
            if (token0 == USDC || token1 == USDC) {
                if (
                    // the other token must be stablecoin-like
                    // 10 * 10 ** uint(IERC20MetadataUpgradeable(address(tokenWithAmtLeft)).decimals()) means
                    // 10 usd in other token decimals
                    amtLeft > 10 * 10 ** uint(IERC20MetadataUpgradeable(address(tokenWithAmtLeft)).decimals())
                ) {
                    // leftover > 10 USD, redo swap & add liquidity
                    extraLpTokenAmt = _reAddLiquidity(amtLeft, tokenWithAmtLeft, token0AmtBef, token1AmtBef);

                } else {
                    // leftover < 10 USD, return to msg.sender
                    tokenWithAmtLeft.safeTransfer(msg.sender, amtLeft);
                }

            } else if (token0 == WETH || token1 == WETH) {
                // the other token value should be similar to weth
                // so use weth to determine amtLeft in usd
                extraLpTokenAmt = _innerReAddLiquidityOrTransferBack(
                    tokenWithAmtLeft,
                    amtLeft,
                    token0AmtBef,
                    token1AmtBef,
                    true
                );

            } else {
                // not pair with usdc or weth, just return leftover to msg.sender
                tokenWithAmtLeft.safeTransfer(msg.sender, amtLeft);
            }

        } else { // not stable pair
            if (tokenWithAmtLeft == USDC) {
                if (amtLeft > 10e6) {
                    // leftover for USDC > 10 USD, redo swap & add liquidity
                    extraLpTokenAmt = _reAddLiquidity(amtLeft, USDC, token0AmtBef, token1AmtBef);

                } else {
                    // leftover < 10 USD, return to msg.sender
                    USDC.safeTransfer(msg.sender, amtLeft);
                }

            } else if (tokenWithAmtLeft != USDC && (token0 == USDC || token1 == USDC)) {
                extraLpTokenAmt = _innerReAddLiquidityOrTransferBack(
                    tokenWithAmtLeft,
                    amtLeft,
                    token0AmtBef,
                    token1AmtBef,
                    false
                );

            } else {
                // not pair with usdc, just return leftover to msg.sender
                tokenWithAmtLeft.safeTransfer(msg.sender, amtLeft);
            }
        }
    }

    function _innerReAddLiquidityOrTransferBack(
        IERC20Upgradeable tokenWithAmtLeft,
        uint amtLeft,
        uint token0AmtBef,
        uint token1AmtBef,
        bool useWeth
    ) private returns (uint extraLpTokenAmt) {
        address tokenIn = useWeth ? address(WETH) : address(tokenWithAmtLeft);

        (uint usdcAmt,) = ROUTER.getAmountOut(amtLeft, tokenIn, address(USDC));
        if (usdcAmt > 10e6) {
            // leftover for token0 > 10 USD, redo swap & add liquidity
            extraLpTokenAmt = _reAddLiquidity(amtLeft, tokenWithAmtLeft, token0AmtBef, token1AmtBef);

        } else {
            // leftover < 10 USD, return to msg.sender
            tokenWithAmtLeft.safeTransfer(msg.sender, amtLeft);
        }
    }

    function _reAddLiquidity(
        uint amount,
        IERC20Upgradeable tokenIn,
        uint token0AmtBef,
        uint token1AmtBef
    ) private returns (uint) {
        IERC20Upgradeable tokenOut = tokenIn == token0 ? token1 : token0;
        uint amountIn = amount / 2;
        uint amountOut = _swap(address(tokenIn), address(tokenOut), stable, amountIn, 0);
        (,, uint lpTokenAmt) = ROUTER.addLiquidity(
            address(tokenIn), address(tokenOut), stable, amountIn, amountOut, 0, 0, address(this), block.timestamp
        );

        // check leftover again and just return to msg.sender if any
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
        require(amountOutLpToken > 0 && user.lpTokenBalance >= amountOutLpToken, "Invalid amount to withdraw");
        require(depositedBlock[msg.sender] != block.number, "No same block withdrawal");

        harvest();

        user.lpTokenBalance = user.lpTokenBalance - amountOutLpToken;
        user.rewardStartAt = user.lpTokenBalance * reward.accRewardPerlpToken / 1e36;
        gauge.withdraw(amountOutLpToken);

        if (token != lpToken) {
            (uint token0Amt, uint token1Amt) = ROUTER.removeLiquidity(
                address(token0), address(token1), stable, amountOutLpToken, 0, 0, address(this), block.timestamp
            );
            if (token == token0) {
                token0Amt += _swap(address(token1), address(token0), stable, token1Amt, amountOutMin);
                amountOutToken = token0Amt;
            } else {
                token1Amt += _swap(address(token0), address(token1), stable, token0Amt, amountOutMin);
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

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function harvest() public virtual {
        uint currentPool = getAllPool();
        Reward memory reward_ = reward;

        _updateAccAtoken(reward_, currentPool);

        // Collect VELO & OP from gauge
        address[] memory tokens = new address[](2);
        tokens[0] = address(VELO);
        tokens[1] = address(OP);
        gauge.getReward(address(this), tokens);

        // Claim OP from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(reward.aToken);
        REWARDS_CONTROLLER.claimRewards(assets, type(uint).max, address(this), address(OP));

        // Calculate WETH amount of VELO
        uint veloAmt = VELO.balanceOf(address(this));
        uint wethAmt = _getAmountOut(veloAmt, address(VELO), address(WETH));

        // Calculate WETH amount of OP
        uint opAmt = OP.balanceOf(address(this));
        wethAmt += _getAmountOut(opAmt, address(OP), address(WETH));

        if (wethAmt > swapThreshold) {
            wethAmt = 0;
            // Swap VELO to WETH
            if (veloAmt > 1 ether) {
                wethAmt = _swap(address(VELO), address(WETH), false, veloAmt, 0);
            }

            // Swap OP to WETH
            if (reward.rewardToken != USDC) {
                // If reward.rewardtoken == USDC, swap OP directly to USDC below
                if (opAmt > 1 ether) {
                    wethAmt += _swap(address(OP), address(WETH), false, opAmt, 0);
                }
            }

            // Swap WETH to reward token
            uint rewardTokenAmt = _swapWethToRewardToken(reward_, wethAmt, opAmt);

            uint fee = 0;
            if (rewardTokenAmt > 0) {
                // Calculate fee
                fee = rewardTokenAmt * yieldFeePerc / 10000;
                rewardTokenAmt -= fee;
                reward.rewardToken.safeTransfer(treasury, fee);

                // Update accRewardPerlpToken
                reward.accRewardPerlpToken += (rewardTokenAmt * 1e36 / currentPool);

                // Deposit reward token into Aave to get interest bearing aToken
                LENDING_POOL.supply(address(reward.rewardToken), rewardTokenAmt, address(this), 0);

                // Update lastATokenAmt
                reward.lastATokenAmt = reward.aToken.balanceOf(address(this));

                accRewardTokenAmt += rewardTokenAmt;
            }

            emit Harvest(veloAmt, rewardTokenAmt, fee);
        }
    }

    function _updateAccAtoken(Reward memory reward_, uint currentPool) private {
        // Update accrued amount of aToken
        uint aTokenAmt = reward_.aToken.balanceOf(address(this));
        if (aTokenAmt > reward_.lastATokenAmt) {
            uint accruedAmt = aTokenAmt - reward_.lastATokenAmt;
            reward.accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
            reward.lastATokenAmt = aTokenAmt;
        }
    }

    function _swapWethToRewardToken(
        Reward memory reward_,
        uint wethAmt,
        uint opAmt
        ) private returns (uint rewardTokenAmt) {
        if (reward_.rewardToken == WBTC) {
            if (wethAmt > 0) {
                IRouter.Route[] memory routes = new IRouter.Route[](2);
                routes[0] = IRouter.Route(address(WETH), address(USDC), false);
                routes[1] = IRouter.Route(address(USDC), address(WBTC), false);
                rewardTokenAmt = ROUTER.swapExactTokensForTokens(
                    wethAmt,
                    0,
                    routes,
                    address(this),
                    block.timestamp
                )[2];
            }

        } else if (reward_.rewardToken == USDC) {
            if (wethAmt > 0) {
                rewardTokenAmt = _swap(address(WETH), address(reward_.rewardToken), false, wethAmt, 0);
            }
            if (opAmt > 1 ether) {
                rewardTokenAmt += _swap(address(OP), address(reward_.rewardToken), false, opAmt, 0);
            }

        } else { // reward_.rewardToken == WETH
            rewardTokenAmt = wethAmt;
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
                    LENDING_POOL.withdraw(address(reward.rewardToken), aTokenAmt, address(this));
                } else {
                    // Last withdrawal
                    LENDING_POOL.withdraw(address(reward.rewardToken), aTokenBal, address(this));
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

    function _swap(
        address tokenIn, address tokenOut, bool stable_, uint amount, uint amountOutMin
    ) private returns (uint amountOut) {
        if (amount > 0) {
            amountOut = ROUTER.swapExactTokensForTokensSimple(
                amount, amountOutMin, tokenIn, tokenOut, stable_, address(this), block.timestamp
            )[1];
        }
    }

    function getLpTokenPriceInETH() internal view returns (uint) {
        (uint reserveToken0, uint reserveToken1) = lpToken.getReserves();

        uint totalReserveTokenInETH;
        uint token0Decimals = uint(IERC20MetadataUpgradeable(address(token0)).decimals());
        uint token1Decimals = uint(IERC20MetadataUpgradeable(address(token1)).decimals());
        if (token0 == WETH) {
            (uint token1PriceInETH,) = ROUTER.getAmountOut(10 ** token1Decimals, address(token1), address(WETH));
            uint reserveToken1InETH = reserveToken1 * token1PriceInETH / 10 ** token1Decimals;
            totalReserveTokenInETH = reserveToken0 + reserveToken1InETH;

        } else if (token1 == WETH) {
            (uint token0PriceInETH,) = ROUTER.getAmountOut(10 ** token0Decimals, address(token0), address(WETH));
            uint reserveToken0InETH = reserveToken0 * token0PriceInETH / 10 ** token0Decimals;
            totalReserveTokenInETH = reserveToken1 + reserveToken0InETH;

        } else { // not pair with WETH
            IRouter.Route[] memory routes = new IRouter.Route[](2);
            uint token0PriceInETH;
            uint token1PriceInETH;
            if (token0 == USDC && stable) {
                (token0PriceInETH,) = ROUTER.getAmountOut(1e6, address(USDC), address(WETH));
                routes[0] = IRouter.Route({
                    from: address(token1),
                    to: address(USDC),
                    stable: true
                });
                routes[1] = IRouter.Route({
                    from: address(USDC),
                    to: address(WETH),
                    stable: false
                });
                token1PriceInETH = ROUTER.getAmountsOut(10 ** token1Decimals, routes)[2];

            } else if (token1 == USDC && stable) {
                routes[0] = IRouter.Route({
                    from: address(token0),
                    to: address(USDC),
                    stable: false
                });
                routes[1] = IRouter.Route({
                    from: address(USDC),
                    to: address(WETH),
                    stable: false
                });
                token0PriceInETH = ROUTER.getAmountsOut(10 ** token0Decimals, routes)[2];
                (token1PriceInETH,) = ROUTER.getAmountOut(1e6, address(USDC), address(WETH));

            } else {
                (token0PriceInETH,) = ROUTER.getAmountOut(10 ** token0Decimals, address(token0), address(WETH));
                (token1PriceInETH,) = ROUTER.getAmountOut(10 ** token1Decimals, address(token1), address(WETH));
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

    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "address 0");
        emit SetTreasury(treasury, treasury_);
        treasury = treasury_;
    }

    function setYieldFeePerc(uint yieldFeePerc_) external onlyOwner {
        require(yieldFeePerc_ <= 1000, "Fee cannot over 10%");
        emit SetYieldFeePerc(yieldFeePerc, yieldFeePerc_);
        yieldFeePerc = yieldFeePerc_;
    }

    function setSwapThreshold(uint swapThreshold_) external onlyOwner {
        emit SetSwapThreshold(swapThreshold, swapThreshold_);
        swapThreshold = swapThreshold_;
    }

    function _getAmountOut(uint amountIn, address tokenIn, address tokenOut) private view returns (uint amountOut) {
        if (amountIn > 0) {
            (amountOut,) = ROUTER.getAmountOut(amountIn, tokenIn, tokenOut);
        } else {
            amountOut = 0;
        }
    }

    function getPricePerFullShareInUSD() public view virtual returns (uint) {
        (, int rawPrice,,,) = WETH_PRICE_FEED.latestRoundData();

        return getLpTokenPriceInETH() * uint(rawPrice) / 1e20; // 6 decimals
    }

    function getAllPool() public view returns (uint) {
        return gauge.balanceOf(address(this));
    }

    function getAllPoolInUSD() external view returns (uint allPoolInUSD) {
        uint allPool = getAllPool();
        if (allPool != 0) {
            allPoolInUSD = allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
        }
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

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
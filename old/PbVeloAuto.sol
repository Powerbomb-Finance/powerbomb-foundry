// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./PbVelo.sol";

contract PbVeloAuto is PbVelo {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;
    using SafeERC20Upgradeable for IPair;

    uint public totalSupply;
    mapping(address => uint) userAlloc;

    function initialize(
        IERC20Upgradeable _VELO,
        IGauge _gauge,
        IERC20Upgradeable, // _rewardToken not applicable on this vault
        ILendingPool, // _lendingPool not applicable on this vault
        IRouter _router,
        IWETH _WETH,
        IChainLink _WETHPriceFeed,
        address _treasury
    ) external override initializer {
        __Ownable_init();

        VELO = _VELO;
        gauge = _gauge;
        address _lpToken = gauge.stake();
        lpToken = IPair(_lpToken);
        (address _token0, address _token1) = lpToken.tokens();
        token0 = IERC20Upgradeable(_token0);
        token1 = IERC20Upgradeable(_token1);
        stable = lpToken.stable();
        router = _router;
        WETH = _WETH;
        WETHPriceFeed = _WETHPriceFeed;
        treasury = _treasury;
        yieldFeePerc = 50; // 2 decimals, 50 = 0.5%

        token0.safeApprove(address(router), type(uint).max);
        token1.safeApprove(address(router), type(uint).max);
        lpToken.safeApprove(address(router), type(uint).max);
        lpToken.safeApprove(address(gauge), type(uint).max);
        VELO.safeApprove(address(router), type(uint).max);

        if (WETH.allowance(address(this), address(router)) == 0) {
            WETH.safeApprove(address(router), type(uint).max);
        }
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable override nonReentrant whenNotPaused {
        require(token == token0 || token == token1 || token == lpToken, "Invalid token");
        require(amount > 0, "Invalid amount");

        uint currentPool = getAllPool();
        if (currentPool > 0) harvest();

        uint token0AmtBef = token0.balanceOf(address(this));
        uint token1AmtBef = token1.balanceOf(address(this));

        if (msg.value != 0) {
            require(amount == msg.value, "Invalid ETH amount");
            WETH.deposit{value: msg.value}();
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
        depositedBlock[msg.sender] = block.number;

        uint lpTokenAmt;
        if (token != lpToken) {
            if (token == token0) {
                uint halfToken0Amt = amount / 2;
                uint token1Amt = swap(address(token0), address(token1), stable, halfToken0Amt, amountOutMin);
                (,,lpTokenAmt) = router.addLiquidity(
                    address(token0), address(token1), stable, halfToken0Amt, token1Amt, 0, 0, address(this), block.timestamp
                );
            } else {
                uint halfToken1Amt = amount / 2;
                uint token0Amt = swap(address(token1), address(token0), stable, halfToken1Amt, amountOutMin);
                (,,lpTokenAmt) = router.addLiquidity(
                    address(token0), address(token1), stable, token0Amt, halfToken1Amt, 0, 0, address(this), block.timestamp
                );
            }

            uint token0AmtLeft = token0.balanceOf(address(this)) - token0AmtBef;
            if (token0AmtLeft > 0) token0.safeTransfer(msg.sender, token0AmtLeft);
            uint token1AmtLeft = token1.balanceOf(address(this)) - token1AmtBef;
            if (token1AmtLeft > 0) token1.safeTransfer(msg.sender, token1AmtLeft);

        } else {
            lpTokenAmt = amount;
        }

        gauge.deposit(lpTokenAmt, 0);
        uint share = currentPool == 0 ? lpTokenAmt : lpTokenAmt * totalSupply / currentPool;
        userAlloc[msg.sender] += share;
        totalSupply += share;

        emit Deposit(address(token), amount, lpTokenAmt);
    }

    function _withdraw(
        IERC20Upgradeable token, uint share, uint amountOutMin
    ) internal override nonReentrant returns (uint amountOutToken) {
        require(token == token0 || token == token1 || token == lpToken, "Invalid token");
        require(share > 0 && userAlloc[msg.sender] > 0, "Invalid share to withdraw");
        require(depositedBlock[msg.sender] != block.number, "Not allow withdraw within same block");

        harvest();

        userAlloc[msg.sender] -= share;
        uint amountOutLpToken = getAllPool() * share / totalSupply;
        totalSupply -= share;
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

        emit Withdraw(address(token), amountOutToken);
    }

    function harvest() public override {
        // Collect VELO from gauge
        address[] memory tokens = new address[](1);
        tokens[0] = address(lpToken);
        gauge.getReward(address(this), tokens);

        uint VELOAmt = VELO.balanceOf(address(this));
        uint WETHAmt;
        if (VELOAmt > 0) {
            (WETHAmt,) = router.getAmountOut(VELOAmt, address(VELO), address(WETH));
        }
        if (WETHAmt > 1e16) { // 0.01 WETH, ~$20 on 31 May 2022
            // Swap VELO to WETH
            WETHAmt = swap(address(VELO), address(WETH), false, VELOAmt, 0);

            // Calculate fee
            uint fee = WETHAmt * yieldFeePerc / 10000;
            WETHAmt -= fee;
            WETH.safeTransfer(treasury, fee);

            // Provide liquidity back to pair.
            uint lpTokenAmt;
            if (token0 == WETH || token1 == WETH) {
                // Determine which one is the other token
                IERC20Upgradeable token = WETH == token0 ? token1 : token0;
                // Swap half WETH to other token
                uint halfWETHAmt = WETHAmt / 2;
                uint otherTokenAmt = swap(address(WETH), address(token), stable, halfWETHAmt, 0);
                // Add liquidity both token
                (,,lpTokenAmt) = router.addLiquidity(
                    address(WETH), address(token), stable, halfWETHAmt, otherTokenAmt, 0, 0, address(this), block.timestamp
                );
            } else {
                // Swap half WETH to each token
                uint halfWETHAmt = WETHAmt / 2;
                uint token0Amt = swap(address(WETH), address(token0), false, halfWETHAmt, 0);
                uint token1Amt = swap(address(WETH), address(token1), false, halfWETHAmt, 0);
                // Add liquidity both token
                (,,lpTokenAmt) = router.addLiquidity(
                    address(token0), address(token1), stable, token0Amt, token1Amt, 0, 0, address(this), block.timestamp
                );
            }

            // Add lpToken to gauge
            gauge.deposit(lpTokenAmt, 0);

            emit Harvest(VELOAmt, WETHAmt, fee);
        }
    }

    function getPricePerFullShareInUSD() public view override returns (uint) {
        (, int rawPrice,,,) = WETHPriceFeed.latestRoundData();

        uint lpTokenAmtPerShare = getAllPool() * 1e18 / totalSupply;
        return lpTokenAmtPerShare * getLpTokenPriceInETH() * uint(rawPrice) / 1e38;
    }

    function getUserBalance(address account) external view override returns (uint) {
        return userAlloc[account];
    }

    function getUserBalanceInUSD(address account) external view override returns (uint) {
        return userAlloc[account] * getPricePerFullShareInUSD() / 1e18;
    }
}

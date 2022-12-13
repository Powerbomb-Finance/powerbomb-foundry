// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PengTogether.sol";
import "../interface/IChainlink.sol";

contract Vault_seth is PengTogether {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;

    // sETH/ETH Curve pool
    IPool constant pool_seth = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // sETH/ETH Curve LP token
    IERC20Upgradeable constant lpToken_seth = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // Curve staking pool for sETH/ETH LP token
    IGauge constant gauge_seth = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
    IChainlink constant ethUsdPriceOracle = IChainlink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function initialize(IRecord _record) external override initializer {
        __Ownable_init();

        admin = msg.sender;
        treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
        yieldFeePerc = 1000;
        record = _record;

        usdc.safeApprove(address(pool_seth), type(uint).max);
        lpToken_seth.safeApprove(address(gauge_seth), type(uint).max);
        lpToken_seth.safeApprove(address(pool_seth), type(uint).max);
        crv.safeApprove(address(swapRouter), type(uint).max);
        op.safeApprove(address(swapRouter), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override {
        _deposit(token, amount, amountOutMin, msg.sender);
    }

    function depositByHelper(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address depositor
    ) external payable override {
        require(msg.sender == helper, "helper only");

        _deposit(token, amount, amountOutMin, depositor);
    }

    function _deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address depositor
    ) internal override nonReentrant whenNotPaused {
        require(token == weth, "weth only");
        require(amount >= 0.1 ether, "min 0.1 ether");
        require(amount == msg.value, "amount != msg.value");

        uint[2] memory amounts;
        amounts[0] = amount;
        uint lpTokenAmt = pool_seth.add_liquidity{value: msg.value}(amounts, amountOutMin);
        gauge_seth.deposit(lpTokenAmt);

        record.updateUser(true, depositor, amount, lpTokenAmt);
        depositedBlock[depositor] = block.number;

        emit Deposit(depositor, amount, lpTokenAmt);
    }

    function withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external override returns (uint actualAmt) {
        actualAmt = _withdraw(token, amount, amountOutMin, msg.sender);
    }

    function withdrawByHelper(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address account
    ) external override returns (uint actualAmt) {
        require(msg.sender == helper, "helper only");

        actualAmt = _withdraw(token, amount, amountOutMin, account);
    }

    function _withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address account
    ) internal override nonReentrant returns (uint actualAmt) {
        require(token == weth, "weth only");
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(account);
        require(depositBal >= amount, "amount > depositBal");
        require(depositedBlock[account] != block.number, "same block deposit withdraw");

        uint withdrawPerc = amount * 1e18 / depositBal;
        uint lpTokenAmt = lpTokenBal * withdrawPerc / 1e18;
        gauge_seth.withdraw(lpTokenAmt);
        actualAmt = pool_seth.remove_liquidity_one_coin(lpTokenAmt, 0, amountOutMin);

        record.updateUser(false, account, amount, lpTokenAmt);

        // eth transfer to msg.sender instead of account because
        // for withdraw() eth transfer to caller (depositor)
        // for withdrawByHelper() eth transfer to pengHelperOp
        (bool success,) = msg.sender.call{value: actualAmt}("");
        require(success);
        emit Withdraw(account, amount, lpTokenAmt, actualAmt);
    }

    function harvest() external override {
        minter.mint(address(gauge_seth)); // to claim crv
        gauge_seth.claim_rewards(); // to claim op
        uint wethAmt;

        // swap crv to weth
        uint crvAmt = crv.balanceOf(address(this));
        if (crvAmt > 1 ether) {
            wethAmt = swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(crv),
                    tokenOut: address(weth),
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: crvAmt,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        // swap op to weth
        uint opAmt = op.balanceOf(address(this));
        if (opAmt > 1 ether) {
            wethAmt += swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(op),
                    tokenOut: address(weth),
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: opAmt,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        // collect fee
        uint fee = wethAmt * yieldFeePerc / 10000;
        wethAmt -= fee;
        weth.safeTransfer(treasury, fee);

        // add up accumulate weth yield
        accWethYield += wethAmt;

        emit Harvest(crvAmt, opAmt, wethAmt, fee);
    }

    function getPricePerFullShareInUSD() public override view returns (uint) {
        (, int latestPrice,,,) = ethUsdPriceOracle.latestRoundData();
        return pool_seth.get_virtual_price() * uint(latestPrice) / 1e20; // 6 decimals
    }

    function getAllPool() public override view returns (uint) {
        return gauge_seth.balanceOf(address(this)); // lpToken, 18 decimals
    }

    function getAllPoolInUSD() external override view returns (uint allPoolInUSD) {
        uint allPool = getAllPool();
        if (allPool > 0) {
            return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
        }
    }

    /// @dev Call this function off-chain by using view
    function getPoolPendingReward() external override returns (uint crvReward, uint opReward) {
        crvReward = gauge_seth.claimable_tokens(address(this));
        opReward = gauge_seth.claimable_reward(address(this), address(op));
    }

    ///@notice user actual balance in usd after deposit into farm (after slippage), 6 decimals
    function getUserBalanceInUSD(address account) external override view returns (uint) {
        (, uint lpTokenBal,,) = record.userInfo(account);
        return lpTokenBal * getPricePerFullShareInUSD() / 1e18;
    }
}
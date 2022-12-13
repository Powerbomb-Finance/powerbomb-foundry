// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./PengTogether.sol";
import "../interface/IChainlink.sol";

contract Vault_seth is PengTogether {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;

    // seth/eth Curve pool
    IPool constant pool_seth = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // seth/eth Curve lp token
    IERC20Upgradeable constant lpToken_seth = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // Curve staking pool for seth/eth lp token
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

    /// @inheritdoc PengTogether
    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override {
        _deposit(token, amount, amountOutMin, msg.sender);
    }

    /// @inheritdoc PengTogether
    function _deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address depositor
    ) internal override nonReentrant whenNotPaused {
        require(token == weth, "weth only");
        require(amount >= 0.1 ether, "min 0.1 ether");
        require(amount == msg.value, "amount != msg.value");

        uint[2] memory amounts; // [eth, seth]
        amounts[0] = amount;
        // add liquidity eth into curve pool to get lp token
        uint lpTokenAmt = pool_seth.add_liquidity{value: msg.value}(amounts, amountOutMin);
        // deposit into curve lp token staking pool for reward
        gauge_seth.deposit(lpTokenAmt);

        // update user info into peng together record contract
        record.updateUser(true, depositor, amount, lpTokenAmt);
        // save block which call this function to check if withdraw within same block
        depositedBlock[depositor] = block.number;

        emit Deposit(depositor, amount, lpTokenAmt);
    }

    /// @inheritdoc PengTogether
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

        // calculate lp token amount to withdraw
        uint lpTokenAmt = lpTokenBal * amount / depositBal;
        // withdraw from curve lp token staking pool
        gauge_seth.withdraw(lpTokenAmt);
        // burn lp token and remove liquidity from curve pool and receive eth
        actualAmt = pool_seth.remove_liquidity_one_coin(lpTokenAmt, 0, amountOutMin);

        // update user info into peng together record contract
        record.updateUser(false, account, amount, lpTokenAmt);

        // eth transfer to msg.sender instead of account because
        // for withdraw() eth transfer to caller (depositor)
        // for withdrawByHelper() eth transfer to pengHelperOp
        // and pengHelperOp help to transfer eth to account
        (bool success,) = msg.sender.call{value: actualAmt}("");
        require(success);
        emit Withdraw(account, amount, lpTokenAmt, actualAmt);
    }

    /// @notice harvest from curve for rewards and sell them for weth
    /// @inheritdoc PengTogether
    function harvest() external override {
        minter.mint(address(gauge_seth)); // to claim crv
        gauge_seth.claim_rewards(); // to claim op
        uint wethAmt = 0;

        // swap crv to weth via uniswap v3
        // no slippage needed because small amount swap
        uint crvAmt = crv.balanceOf(address(this));
        if (crvAmt > 1 ether) { // minimum swap 1e18 crv
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

        // swap op to weth via uniswap v3
        // no slippage needed because small amount swap
        uint opAmt = op.balanceOf(address(this));
        if (opAmt > 1 ether) { // minimum swap 1e18 op
            wethAmt += swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(op),
                    tokenOut: address(weth),
                    fee: 3000, // 0.3%
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

    /// @notice calculate usd value per lp token
    /// @inheritdoc PengTogether
    function getPricePerFullShareInUSD() public override view returns (uint) {
        // get latest price from chainlink
        (, int latestPrice,,,) = ethUsdPriceOracle.latestRoundData();
        // get_virtual_price() return 18 decimals, latestPrice 8 decimals
        return pool_seth.get_virtual_price() * uint(latestPrice) / 1e20; // 6 decimals
    }

    /// @notice get all lp token amount stake in curve farm(gauge)
    /// @inheritdoc PengTogether
    function getAllPool() public override view returns (uint) {
        return gauge_seth.balanceOf(address(this)); // 18 decimals
    }

    /// @notice get current pending rewards for harvest
    /// @dev Call this function off-chain by using view
    /// @return crvReward pendig crv reward
    /// @return opReward pendig op reward
    function getPoolPendingReward() external override returns (uint crvReward, uint opReward) {
        crvReward = gauge_seth.claimable_tokens(address(this));
        opReward = gauge_seth.claimable_reward(address(this), address(op));
    }
}
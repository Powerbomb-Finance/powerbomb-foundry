// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./PengTogether.sol";
import "../interface/IChainlink.sol";

/// @title seth/eth curve pool edition
/// @author siew
contract Vault_seth is PengTogether {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;

    // seth/eth Curve pool
    IPool constant POOL_SETH = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // seth/eth Curve lp token
    IERC20Upgradeable constant LP_TOKEN_SETH = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    // Curve staking pool for seth/eth lp token
    IGauge constant GAUGE_SETH = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);
    IChainlink constant ETH_USD_PRICE_ORACLE = IChainlink(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function initialize(IRecord record_) external override initializer {
        __Ownable_init();

        admin = msg.sender;
        treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
        yieldFeePerc = 1000;
        record = record_;

        USDC.safeApprove(address(POOL_SETH), type(uint).max);
        LP_TOKEN_SETH.safeApprove(address(GAUGE_SETH), type(uint).max);
        LP_TOKEN_SETH.safeApprove(address(POOL_SETH), type(uint).max);
        CRV.safeApprove(address(SWAP_ROUTER), type(uint).max);
        OP.safeApprove(address(SWAP_ROUTER), type(uint).max);
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
        require(token == WETH, "weth only");
        require(amount >= 0.1 ether, "min 0.1 ether");
        require(amount == msg.value, "amount != msg.value");

        // save block which call this function to check if withdraw within same block
        depositedBlock[depositor] = block.number;

        uint[2] memory amounts; // [eth, seth]
        amounts[0] = amount;
        // add liquidity eth into curve pool to get lp token
        uint lpTokenAmt = POOL_SETH.add_liquidity{value: msg.value}(amounts, amountOutMin);
        // deposit into curve lp token staking pool for reward
        GAUGE_SETH.deposit(lpTokenAmt);

        // update user info into peng together record contract
        record.updateUser(true, depositor, amount, lpTokenAmt);

        emit Deposit(depositor, amount, lpTokenAmt);
    }

    /// @inheritdoc PengTogether
    function _withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address account
    ) internal override nonReentrant returns (uint actualAmt) {
        require(token == WETH, "weth only");
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(account);
        require(depositBal >= amount, "amount > depositBal");
        require(depositedBlock[account] != block.number, "same block deposit withdraw");

        // calculate lp token amount to withdraw
        uint lpTokenAmt = lpTokenBal * amount / depositBal;
        // withdraw from curve lp token staking pool
        GAUGE_SETH.withdraw(lpTokenAmt);
        // burn lp token and remove liquidity from curve pool and receive eth
        actualAmt = POOL_SETH.remove_liquidity_one_coin(lpTokenAmt, 0, amountOutMin);

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
        MINTER.mint(address(GAUGE_SETH)); // to claim crv
        GAUGE_SETH.claim_rewards(); // to claim op
        uint wethAmt = 0;

        // swap crv to weth via uniswap v3
        // no slippage needed because small amount swap
        uint crvAmt = CRV.balanceOf(address(this));
        if (crvAmt > 1 ether) { // minimum swap 1e18 crv
            wethAmt = SWAP_ROUTER.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(CRV),
                    tokenOut: address(WETH),
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
        uint opAmt = OP.balanceOf(address(this));
        if (opAmt > 1 ether) { // minimum swap 1e18 op
            wethAmt += SWAP_ROUTER.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(OP),
                    tokenOut: address(WETH),
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
        WETH.safeTransfer(treasury, fee);

        // add up accumulate weth yield
        accWethYield += wethAmt;

        emit Harvest(crvAmt, opAmt, wethAmt, fee);
    }

    /// @notice calculate usd value per lp token
    /// @inheritdoc PengTogether
    function getPricePerFullShareInUSD() public override view returns (uint) {
        // get latest price from chainlink
        (, int latestPrice,,,) = ETH_USD_PRICE_ORACLE.latestRoundData();
        // get_virtual_price() return 18 decimals, latestPrice 8 decimals
        return POOL_SETH.get_virtual_price() * uint(latestPrice) / 1e20; // 6 decimals
    }

    /// @inheritdoc PengTogether
    function getAllPool() public override view returns (uint) {
        return GAUGE_SETH.balanceOf(address(this)); // 18 decimals
    }

    /// @inheritdoc PengTogether
    function getPoolPendingReward() external override returns (uint crvReward, uint opReward) {
        crvReward = GAUGE_SETH.claimable_tokens(address(this));
        opReward = GAUGE_SETH.claimable_reward(address(this), address(OP));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PengTogether.sol";

contract Vault_seth is PengTogether {

    IPool constant pool_seth = IPool(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IERC20Upgradeable constant lpToken_seth = IERC20Upgradeable(0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E);
    IGauge constant gauge_seth = IGauge(0xCB8883D1D8c560003489Df43B30612AAbB8013bb);

    function initialize(IRecord _record) external override initializer {
        __Ownable_init();

        admin = msg.sender;
        treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
        yieldFeePerc = 1000;
        record = _record;

        usdc.approve(address(pool_seth), type(uint).max);
        lpToken_seth.approve(address(gauge_seth), type(uint).max);
        lpToken_seth.approve(address(pool_seth), type(uint).max);
        crv.approve(address(swapRouter), type(uint).max);
        op.approve(address(swapRouter), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable override nonReentrant whenNotPaused {
        require(token == weth, "weth only");
        require(amount >= 0.1 ether, "min 0.1 ether");
        require(amount == msg.value, "amount != msg.value");

        uint[2] memory amounts;
        amounts[0] = amount;
        uint lpTokenAmt = pool_seth.add_liquidity{value: msg.value}(amounts, amountOutMin);
        gauge_seth.deposit(lpTokenAmt);

        record.updateUser(true, msg.sender, amount, lpTokenAmt);
        depositedBlock[msg.sender] = block.number;

        emit Deposit(msg.sender, amount, lpTokenAmt);
    }

    function withdraw(IERC20Upgradeable token, uint amount, uint amountOutMin) external override nonReentrant {
        require(token == weth, "weth only");
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(msg.sender);
        require(depositBal >= amount, "amount > depositBal");
        require(depositedBlock[msg.sender] != block.number, "same block deposit withdraw");

        uint withdrawPerc = amount * 1e18 / depositBal;
        uint lpTokenAmt = lpTokenBal * withdrawPerc / 1e18;
        gauge_seth.withdraw(lpTokenAmt);
        uint actualAmt = pool_seth.remove_liquidity_one_coin(lpTokenAmt, 0, amountOutMin);

        record.updateUser(false, msg.sender, amount, lpTokenAmt);

        (bool success,) = msg.sender.call{value: actualAmt}("");
        require(success);
        emit Withdraw(msg.sender, amount, lpTokenAmt, actualAmt);
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
        weth.transfer(treasury, fee);

        // add up accumulate weth yield
        accWethYield += wethAmt;

        emit Harvest(crvAmt, opAmt, wethAmt, fee);
    }

    function getPricePerFullShareInUSD() public override view returns (uint) {
        return pool_seth.get_virtual_price() / 1e12; // 6 decimals
    }

    function getAllPool() public override view returns (uint) {
        return gauge_seth.balanceOf(address(this)); // lpToken, 18 decimals
    }
}
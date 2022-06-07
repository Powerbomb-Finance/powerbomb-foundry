// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./PbCrvTriReward.sol";

contract PbCrvTriRewardBTC is PbCrvTriReward {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

    function initialize(address _vault, address _treasury) external override initializer {
        __Ownable_init();

        vault = _vault;
        treasury = _treasury;

        CRV.safeApprove(address(swapRouter), type(uint).max);
        WBTC.safeApprove(address(lendingPool), type(uint).max);
    }

    function harvest(uint amount) external override onlyVault {
        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(WETH));
        IERC20Upgradeable aToken = IERC20Upgradeable(aTokenAddr);

        // Update accrued amount of aToken
        uint currentPool = getAllPool();
        uint aTokenAmt = aToken.balanceOf(address(this));
        if (aTokenAmt > lastATokenAmt) {
            uint accruedAmt = aTokenAmt - lastATokenAmt;
            accRewardPerlpToken += (accruedAmt * 1e36 / currentPool);
            lastATokenAmt = aTokenAmt;
        }

        CRV.safeTransferFrom(msg.sender, address(this), amount);
        if (amount > 1e18) {
            ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: abi.encodePacked(address(CRV), uint24(10000), address(WETH), uint24(3000), address(WBTC)),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0
                });
            uint WBTCAmt = swapRouter.exactInput(params);

            // Calculate fee
            uint fee = WBTCAmt * yieldFeePerc / 10000;
            WBTCAmt -= fee;
            WBTC.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (WBTCAmt * 1e36 / currentPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(WBTC), WBTCAmt, address(this), 0);

            // Update lastATokenAmt
            lastATokenAmt = aToken.balanceOf(address(this));
        }
    }
}
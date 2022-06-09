// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./PbCrvTriReward.sol";

contract PbCrvTriRewardUSDC is PbCrvTriReward {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    function initialize(address _vault, address _treasury) external override initializer {
        __Ownable_init();

        vault = _vault;
        treasury = _treasury;
        yieldFeePerc = 500;

        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(USDC));
        aToken = IERC20Upgradeable(aTokenAddr);

        CRV.safeApprove(address(swapRouter), type(uint).max);
        USDC.safeApprove(address(lendingPool), type(uint).max);
    }

    /// @notice Swap as little amount as possible to prevent sandwich attack because amountOutMinimum set to 0
    function harvest(uint amount) external override onlyVault nonReentrant {
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
                    path: abi.encodePacked(address(CRV), uint24(10000), address(WETH), uint24(500), address(USDC)),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0
                });
            uint USDCAmt = swapRouter.exactInput(params);

            // Calculate fee
            uint fee = USDCAmt * yieldFeePerc / 10000;
            USDCAmt -= fee;
            USDC.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (USDCAmt * 1e36 / currentPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(USDC), USDCAmt, address(this), 0);

            // Update lastATokenAmt
            lastATokenAmt = aToken.balanceOf(address(this));

            emit Harvest(amount, USDCAmt, fee);
        }
    }

    function claim(address account) external override {
        require(msg.sender == vault || msg.sender == account, "Only claim by account or vault");

        User storage user = userInfo[account];
        if (user.balance > 0) {
            // Calculate user reward
            uint aTokenAmt = (user.balance * accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (aTokenAmt > 0) {
                user.rewardStartAt += aTokenAmt;

                // Update lastATokenAmt
                if (lastATokenAmt >= aTokenAmt) {
                    lastATokenAmt -= aTokenAmt;
                } else {
                    // Last claim: to prevent arithmetic underflow error due to minor variation
                    lastATokenAmt = 0;
                }

                // Withdraw aToken to USDC
                uint aTokenBal = aToken.balanceOf(address(this));
                if (aTokenBal >= aTokenAmt) {
                    lendingPool.withdraw(address(USDC), aTokenAmt, address(this));
                } else {
                    // Last withdraw: to prevent withdrawal fail from lendingPool due to minor variation
                    lendingPool.withdraw(address(USDC), aTokenBal, address(this));
                }

                // Transfer USDC to user
                uint USDCAmt = USDC.balanceOf(address(this));
                USDC.safeTransfer(account, USDCAmt);

                emit Claim(account, USDCAmt);
            }
        }
    }
}
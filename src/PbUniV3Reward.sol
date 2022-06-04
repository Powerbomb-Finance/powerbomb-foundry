// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ISwapRouter.sol";
import "../interface/ILendingPool.sol";
import "../interface/IVault.sol";

contract PbUniV3Reward is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ILendingPool public constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave Pool V3

    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;

    struct User {
        uint balance;
        uint rewardStartAt;
    }
    // userInfo[userAddr][rewardTokenAddr]
    mapping(address => mapping(address => User)) public userInfo;

    struct Reward {
        uint accRewardPerlpToken;
        uint basePool;
        IERC20Upgradeable ibRewardToken;
        uint lastIbRewardTokenAmt;
    }
    // rewardInfo[rewardTokenAddr]
    mapping(address => Reward) public rewardInfo;

    address public vault;
    uint public yieldFeePerc; // 2 decimals, 500 = 5%
    address public treasury;

    event RecordDeposit(address indexed account, uint amount, address indexed rewardToken);
    event RecordWithdraw(address indexed account, uint amount, address indexed rewardToken);
    event Harvest(uint amount0, uint amount1, address indexed rewardToken, uint rewardTokenAmt, uint fee);
    event ClaimReward(address indexed account, address indexed rewardToken, uint rewardTokenAmt);
    event SetVault(address oldVault, address newVault);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(address _vault, uint _yieldFeePerc, address _treasury) external initializer {
        __Ownable_init();

        vault = _vault;
        yieldFeePerc = _yieldFeePerc;
        treasury = _treasury;

        token0 = IERC20Upgradeable(IVault(_vault).token0());
        token0.safeApprove(address(swapRouter), type(uint).max);
        token1 = IERC20Upgradeable(IVault(_vault).token1());
        token1.safeApprove(address(swapRouter), type(uint).max);

        address ibRewardTokenAddr;
        // Get ibRewardToken address and approve rewardToken to lendingPool
        {
            // WBTC
            (,,,,,,,,ibRewardTokenAddr) = lendingPool.getReserveData(address(WBTC));
            rewardInfo[address(WBTC)].ibRewardToken = IERC20Upgradeable(ibRewardTokenAddr);
            WBTC.safeApprove(address(lendingPool), type(uint).max);

            // WETH
            (,,,,,,,,ibRewardTokenAddr) = lendingPool.getReserveData(address(WETH));
            rewardInfo[address(WETH)].ibRewardToken = IERC20Upgradeable(ibRewardTokenAddr);
            WETH.safeApprove(address(lendingPool), type(uint).max);
        }
    }

    /// @notice Record deposit info from vault
    function recordDeposit(address account, uint amount, address rewardToken) public onlyVault {
        User storage user = userInfo[account][rewardToken];
        user.balance += amount;
        user.rewardStartAt += (amount * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool += amount;

        emit RecordDeposit(account, amount, rewardToken);
    }

    /// @notice Record withdraw info from vault
    function recordWithdraw(address account, uint amount, address rewardToken) public onlyVault {
        User storage user = userInfo[account][rewardToken];
        user.balance -= amount;
        user.rewardStartAt = (user.balance * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool -= amount;

        emit RecordWithdraw(account, amount, rewardToken);
    }

    // @notice Transfer Uniswap fees from vault and turn them into rewardToken
    function harvest(uint amount0, uint amount1) external onlyVault nonReentrant {
        token0.safeTransferFrom(vault, address(this), amount0);
        token1.safeTransferFrom(vault, address(this), amount1);

        // Get pool info
        uint WBTCPool = rewardInfo[address(WBTC)].basePool;
        uint WETHPool = rewardInfo[address(WETH)].basePool;
        uint totalPool = WBTCPool + WETHPool;

        // Calculate token amount distributed for each rewardToken
        // WBTC
        uint token0AmtForWBTC = amount0 * WBTCPool / totalPool;
        uint token1AmtForWBTC = amount1 * WBTCPool / totalPool;
        if (token0AmtForWBTC > 0 || token1AmtForWBTC > 0) {
            _harvest(WBTC, token0AmtForWBTC, token1AmtForWBTC);
        }

        // WETH
        uint token0AmtForWETH = amount0 * WETHPool / totalPool;
        uint token1AmtForWETH = amount1 * WETHPool / totalPool;
        if (token0AmtForWETH > 0 || token1AmtForWETH > 0) {
            _harvest(WETH, token0AmtForWETH, token1AmtForWETH);
        }
    }

    function _harvest(
        IERC20Upgradeable rewardToken,
        uint amount0,
        uint amount1
    ) private {
        Reward memory reward = rewardInfo[address(rewardToken)];

        // Update accrued amount of ibRewardToken
        uint basePool = reward.basePool;
        uint ibRewardTokenAmt = reward.ibRewardToken.balanceOf(address(this));
        if (ibRewardTokenAmt > reward.lastIbRewardTokenAmt) {
            uint accruedAmt = ibRewardTokenAmt - reward.lastIbRewardTokenAmt;
            rewardInfo[address(rewardToken)].accRewardPerlpToken += (accruedAmt * 1e36 / basePool);
        }

        // Swap collected Uniswap fees to rewardToken
        uint rewardTokenAmt;
        if (token0 == rewardToken) {
            // Only swap token1 to rewardToken
            rewardTokenAmt = amount0;
            rewardTokenAmt += _swap(address(token1), address(rewardToken), amount1);
        } else if (token1 == rewardToken) {
            // Only swap token0 to rewardToken
            rewardTokenAmt = amount1;
            rewardTokenAmt += _swap(address(token0), address(rewardToken), amount0);
        } else {
            // Swap both tokens to rewardToken
            rewardTokenAmt = _swap(address(token0), address(rewardToken), amount0);
            rewardTokenAmt += _swap(address(token1), address(rewardToken), amount1);
        }

        // Sanity check for rewardTokenAmt: too small amount swap to WBTC will result 0
        uint fee;
        if (rewardTokenAmt > 0) {
            // Calculate treasury fee
            fee = rewardTokenAmt * yieldFeePerc / 10000;
            rewardTokenAmt -= fee;
            rewardToken.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            rewardInfo[address(rewardToken)].accRewardPerlpToken += (rewardTokenAmt * 1e36 / basePool);

            // Supply reward token into Aave to get ibRewardToken
            lendingPool.supply(address(rewardToken), rewardTokenAmt, address(this), 0);
        }

        // Update lastIbRewardTokenAmt
        rewardInfo[address(rewardToken)].lastIbRewardTokenAmt = reward.ibRewardToken.balanceOf(address(this));

        emit Harvest(amount0, amount1, address(rewardToken), rewardTokenAmt, fee);
    }

    /// @notice Claim all rewardToken at once
    /// @notice Harvest will call on vault side first before claim to provide updated reward to user
    function claim(address account) external onlyVault nonReentrant {
        _claim(account, WBTC);
        _claim(account, WETH);
    }

    /// @notice Claim rewardToken
    function _claim(address account, IERC20Upgradeable rewardToken) private {
        User storage user = userInfo[account][address(rewardToken)];
        if (user.balance > 0) {
            Reward memory reward = rewardInfo[address(rewardToken)];

            // Calculate user reward
            uint ibRewardTokenAmt = (user.balance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (ibRewardTokenAmt > 0) {
                user.rewardStartAt += ibRewardTokenAmt;

                // Update lastIbRewardTokenAmt
                if (reward.lastIbRewardTokenAmt >= ibRewardTokenAmt) {
                    rewardInfo[address(rewardToken)].lastIbRewardTokenAmt -= ibRewardTokenAmt;
                } else {
                    // Last claim: to prevent arithmetic underflow error due to minor variation
                    rewardInfo[address(rewardToken)].lastIbRewardTokenAmt = 0;
                }

                // Withdraw ibRewardToken to rewardToken
                uint ibRewardTokenBal = reward.ibRewardToken.balanceOf(address(this));
                if (ibRewardTokenBal >= ibRewardTokenAmt) {
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenAmt, address(this));
                } else {
                    // Last withdraw: to prevent withdrawal fail from lendingPool due to minor variation
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenBal, address(this));
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = rewardToken.balanceOf(address(this));
                rewardToken.safeTransfer(account, rewardTokenAmt);

                emit ClaimReward(account, address(rewardToken), rewardTokenAmt);
            }
        }
    }

    /// @notice Swap fee hardcode to 0.05%
    /// @notice Swap as little amount as possible to prevent sandwich attack because amountOutMinimum set to 0
    function _swap(address tokenIn, address tokenOut, uint amountIn) private returns (uint amountOut) {
        if (amountIn == 0) return 0;

        if (tokenOut == address(WBTC) && tokenIn != address(WETH)) {
            // The only good liquidity swap to WBTC is WETH-WBTC in Arbitrum, so all tokens swap to WETH need route through WETH
            ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: abi.encodePacked(address(tokenIn), uint24(500), address(WETH), uint24(500), address(WBTC)),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0
                });
            amountOut = swapRouter.exactInput(params);

        } else {
            // Normal swap
            ISwapRouter.ExactInputSingleParams memory params = 
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: 500,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            amountOut = swapRouter.exactInputSingle(params);
        }
    }

    function setVault(address _vault) external onlyOwner {
        emit SetVault(vault, _vault);
        vault = _vault;
    }

    function setYieldFeePerc(uint _yieldFeePerc) external onlyOwner {
        require(_yieldFeePerc <= 1000, "Fee cannot over 10%");
        emit SetYieldFeePerc(yieldFeePerc, _yieldFeePerc);
        yieldFeePerc = _yieldFeePerc;

    }

    function setTreasury(address _treasury) external onlyOwner {
        emit SetTreasury(treasury, _treasury);
        treasury = _treasury;

    }

    function getAllPool() external view returns (uint) {
        return rewardInfo[address(WBTC)].basePool + rewardInfo[address(WETH)].basePool;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

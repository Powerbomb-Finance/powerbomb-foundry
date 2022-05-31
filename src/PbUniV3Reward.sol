// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ISwapRouter.sol";
import "../interface/ILendingPool.sol";
import "../interface/IIncentivesController.sol";

import "forge-std/Test.sol";

contract PbUniV3Reward is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ILendingPool public constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave Pool V3

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
    uint public feePerc; // 2 decimals, 500 = 5%
    address public treasury;

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(address _vault, uint _feePerc, address _treasury) external initializer {
        __Ownable_init();

        vault = _vault;
        feePerc = _feePerc;
        treasury = _treasury;

        address ibRewardTokenAddr;
        {
            (,,,,,,,,ibRewardTokenAddr) = lendingPool.getReserveData(address(WBTC));
            rewardInfo[address(WBTC)].ibRewardToken = IERC20Upgradeable(ibRewardTokenAddr);
            setApproval(WBTC, address(lendingPool));

            (,,,,,,,,ibRewardTokenAddr) = lendingPool.getReserveData(address(WETH));
            rewardInfo[address(WETH)].ibRewardToken = IERC20Upgradeable(ibRewardTokenAddr);
            setApproval(WETH, address(lendingPool));
        }
    }

    function recordDeposit(address account, uint amount, address rewardToken) public onlyVault {
        User storage user = userInfo[account][rewardToken];
        user.balance += amount;
        user.rewardStartAt += (amount * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool += amount;
        // emit Record(account, amount, rewardToken, chainId, RecordType.DEPOSIT);
    }

    function recordWithdraw(address account, uint amount, address rewardToken) public onlyVault {
        User storage user = userInfo[account][rewardToken];
        user.balance -= amount;
        user.rewardStartAt = (user.balance * rewardInfo[rewardToken].accRewardPerlpToken / 1e36);
        rewardInfo[rewardToken].basePool -= amount;
        // emit Record(account, amount, rewardToken, chainId, RecordType.WITHDRAW);
    }

    function harvest(IERC20Upgradeable token0, IERC20Upgradeable token1, uint amount0, uint amount1) external onlyVault {
        token0.safeTransferFrom(vault, address(this), amount0);
        token1.safeTransferFrom(vault, address(this), amount1);

        uint WBTCPool = rewardInfo[address(WBTC)].basePool;
        uint WETHPool = rewardInfo[address(WETH)].basePool;
        uint totalPool = WBTCPool + WETHPool;

        uint token0AmtForWBTC = amount0 * WBTCPool / totalPool;
        uint token1AmtForWBTC = amount1 * WBTCPool / totalPool;
        if (token0AmtForWBTC > 0 || token1AmtForWBTC > 0) {
            _harvest(token0, token1, WBTC, token0AmtForWBTC, token1AmtForWBTC);
        }

        uint token0AmtForWETH = amount0 * WETHPool / totalPool;
        uint token1AmtForWETH = amount1 * WETHPool / totalPool;
        if (token0AmtForWETH > 0 || token1AmtForWETH > 0) {
            _harvest(token0, token1, WETH, token0AmtForWETH, token1AmtForWETH);
        }
    }

    function _harvest(
        IERC20Upgradeable token0,
        IERC20Upgradeable token1,
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
            rewardTokenAmt = amount0;
            rewardTokenAmt += _swap(address(token1), address(rewardToken), amount1);
        } else if (token1 == rewardToken) {
            rewardTokenAmt = amount1;
            rewardTokenAmt += _swap(address(token0), address(rewardToken), amount0);
        } else {
            rewardTokenAmt = _swap(address(token0), address(rewardToken), amount0);
            rewardTokenAmt += _swap(address(token1), address(rewardToken), amount1);
        }

        // Calculate treasury fee
        uint fee = rewardTokenAmt * feePerc / 10000;
        rewardTokenAmt -= fee;
        rewardToken.safeTransfer(treasury, fee);

        // Update accRewardPerlpToken
        rewardInfo[address(rewardToken)].accRewardPerlpToken += (rewardTokenAmt * 1e36 / basePool);

        // Supply reward token into Aave to get interest bearing aToken
        lendingPool.supply(address(rewardToken), rewardTokenAmt, address(this), 0);

        // Update lastIbRewardTokenAmt
        rewardInfo[address(rewardToken)].lastIbRewardTokenAmt = reward.ibRewardToken.balanceOf(address(this));

        // emit Harvest(amount0, amount1, address(rewardToken), rewardTokenAmt, fee);
    }

    function claim(address account) external {
        _claim(account, WBTC);
        _claim(account, WETH);
    }

    function _claim(address account, IERC20Upgradeable rewardToken) private {
        User storage user = userInfo[account][address(rewardToken)];
        if (user.balance > 0) {
            Reward memory reward = rewardInfo[address(rewardToken)];

            // Calculate user reward
            uint ibRewardTokenAmt = (user.balance * reward.accRewardPerlpToken / 1e36) - user.rewardStartAt;
            if (ibRewardTokenAmt > 0) {
                user.rewardStartAt += ibRewardTokenAmt;

                // Update lastIbRewardTokenAmt
                if (reward.lastIbRewardTokenAmt > ibRewardTokenAmt) {
                    rewardInfo[address(rewardToken)].lastIbRewardTokenAmt -= ibRewardTokenAmt;
                } else {
                    rewardInfo[address(rewardToken)].lastIbRewardTokenAmt = 0;
                }

                // Withdraw ibRewardToken to rewardToken
                uint ibRewardTokenBal = reward.ibRewardToken.balanceOf(address(this));
                if (ibRewardTokenBal > ibRewardTokenAmt) {
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenAmt, address(this));
                } else {
                    lendingPool.withdraw(address(rewardToken), ibRewardTokenBal, address(this));
                }

                // Transfer rewardToken to user
                uint rewardTokenAmt = rewardToken.balanceOf(address(this));
                rewardToken.safeTransfer(account, rewardTokenAmt);

                // emit ClaimReward(account, ibRewardTokenAmt, rewardTokenAmt);
            }
        }
    }

    /// @notice Swap fee hardcode to 0.05%
    /// @notice Swap as little amount as possible to prevent sandwich attack because amountOutMinimum set to 0
    function _swap(address tokenIn, address tokenOut, uint amount) private returns (uint) {
        if (amount == 0) return 0;
        // console.log("checkpoint swap");

        if (tokenOut == address(WBTC) && tokenIn != address(WETH)) {
            // console.log("if");
            ISwapRouter.ExactInputParams memory params = 
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(address(tokenIn), uint24(500), address(WETH), uint24(500), address(WBTC)),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0
            });
            // swapRouter.exactInput(params);
            // console.log(WBTC.balanceOf(address(this)));
            // return WBTC.balanceOf(address(this));
            return swapRouter.exactInput(params);
        } else {
            // console.log("else");
            // console.log(amount);
            ISwapRouter.ExactInputSingleParams memory params = 
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: 500,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            // swapRouter.exactInputSingle(params);
            // console.log(WBTC.balanceOf(address(this)));
            // return WBTC.balanceOf(address(this));
            return swapRouter.exactInputSingle(params);
        }
    }

    // /// @notice Swap fee hardcode to 0.05% for both path
    // /// @notice Swap as little amount as possible to prevent sandwich attack because amountOutMinimum set to 0
    // function _swap3(address tokenIn, address tokenOut, uint amount) private returns (uint) {
    //     ISwapRouter.ExactInputParams memory params = 
    //         ISwapRouter.ExactInputParams({
    //             path: abi.encodePacked(address(tokenIn), uint24(500), address(WETH), uint24(500), address(tokenOut)),
    //             recipient: address(this),
    //             deadline: block.timestamp,
    //             amountIn: amount,
    //             amountOutMinimum: 0
    //         });
    //     return swapRouter.exactInput(params);
    // }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function setApproval(IERC20Upgradeable token, address destination) public onlyOwner {
        token.safeApprove(destination, type(uint).max);
    }

    function getAllPool() external view returns (uint) {
        return rewardInfo[address(WBTC)].basePool + rewardInfo[address(WETH)].basePool;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

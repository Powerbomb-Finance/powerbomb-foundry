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

contract PbCrvTriReward is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // Uniswap V3
    ILendingPool constant lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave Lending Pool

    struct User {
        uint balance;
        uint rewardStartAt;
    }
    mapping(address => User) public userInfo;
    
    IERC20Upgradeable public aToken;
    uint public lastATokenAmt;
    uint public accRewardPerlpToken;
    uint private basePool;
    uint public yieldFeePerc;
    address public treasury;
    address public vault;

    event RecordDeposit(address indexed account, uint amount);
    event RecordWithdraw(address indexed account, uint amount);
    event Harvest(uint harvestedTokenAmt, uint swappedRewardTokenAmtAfterFee, uint fee);
    event Claim(address indexed account, uint rewardTokenAmt);
    event SetVault(address oldVault, address newVault);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetYieldFeePerc(uint oldYieldFeePerc, uint newYieldFeePerc);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(address _vault, address _treasury) external virtual initializer {
        __Ownable_init();

        vault = _vault;
        treasury = _treasury;
        yieldFeePerc = 500;

        (,,,,,,,, address aTokenAddr) = lendingPool.getReserveData(address(WETH));
        aToken = IERC20Upgradeable(aTokenAddr);

        CRV.safeApprove(address(swapRouter), type(uint).max);
        WETH.safeApprove(address(lendingPool), type(uint).max);
    }

    /// @notice Record deposit info from vault
    function recordDeposit(address account, uint amount) external onlyVault {
        User storage user = userInfo[account];
        user.balance += amount;
        user.rewardStartAt += (amount * accRewardPerlpToken / 1e36);
        basePool += amount;

        emit RecordDeposit(account, amount);
    }

    /// @notice Record withdraw info from vault
    function recordWithdraw(address account, uint amount) external onlyVault {
        User storage user = userInfo[account];
        user.balance -= amount;
        user.rewardStartAt = (user.balance * accRewardPerlpToken / 1e36);
        basePool -= amount;

        emit RecordWithdraw(account, amount);
    }

    /// @notice Swap as little amount as possible to prevent sandwich attack because amountOutMinimum set to 0
    function harvest(uint amount) external virtual onlyVault nonReentrant {
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
            ISwapRouter.ExactInputSingleParams memory params = 
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(CRV),
                    tokenOut: address(WETH),
                    fee: 10000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            uint WETHAmt = swapRouter.exactInputSingle(params);

            // Calculate fee
            uint fee = WETHAmt * yieldFeePerc / 10000;
            WETHAmt -= fee;
            WETH.safeTransfer(treasury, fee);

            // Update accRewardPerlpToken
            accRewardPerlpToken += (WETHAmt * 1e36 / currentPool);

            // Deposit reward token into Aave to get interest bearing aToken
            lendingPool.supply(address(WETH), WETHAmt, address(this), 0);

            // Update lastATokenAmt
            lastATokenAmt = aToken.balanceOf(address(this));

            emit Harvest(amount, WETHAmt, fee);
        }
    }

    function claim(address account) external virtual {
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

                // Withdraw aToken to WETH
                uint aTokenBal = aToken.balanceOf(address(this));
                if (aTokenBal >= aTokenAmt) {
                    lendingPool.withdraw(address(WETH), aTokenAmt, address(this));
                } else {
                    // Last withdraw: to prevent withdrawal fail from lendingPool due to minor variation
                    lendingPool.withdraw(address(WETH), aTokenBal, address(this));
                }

                // Transfer WETH to user
                uint WETHAmt = WETH.balanceOf(address(this));
                WETH.safeTransfer(account, WETHAmt);

                emit Claim(account, WETHAmt);
            }
        }
    }

    function getAllPool() public view returns (uint) {
        return basePool;
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

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
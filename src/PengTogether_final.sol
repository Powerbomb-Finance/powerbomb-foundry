// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IZap.sol";
import "../interface/IMinter.sol";
import "../interface/IPool.sol";
import "../interface/IGauge.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IRecord.sol";
import "../interface/IWETH.sol";
// import "../interface/IStargateRouterETH.sol";

interface IVault {
    function depositOnBehalf(uint amount, address account) external;
    function getUserBalance(address account) external view returns (uint);
    function getUserBalanceInUSD(address account) external view returns (uint);
    function withdraw(address token, uint lpTokenAmt, uint amountOutMin) external;
    function claim() external;
    function harvest() external;
}

/// @title deposit/withdraw funds from/to curve pool, harvest, convert to eth and bridge to ethereum
/// @author siew
contract PengTogether_final is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;

    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    // susd/3crv curve pool
    IPool constant POOL = IPool(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    // susd/3crv curve lp token
    IERC20Upgradeable constant LP_TOKEN = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    // curve zap to deposit usdt/usdc/dai directly into susd/3crv
    // because susd/3crv only accept susd & 3crv token
    IZap constant ZAP = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    // curve staking pool for susd/3crv lp token
    IGauge constant GAUGE = IGauge(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
    // curve contract to mint crv as reward
    IMinter constant MINTER = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    // Uniswap V3 router
    ISwapRouter constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // IStargateRouterETH constant STARGATE_ROUTER_ETH = IStargateRouterETH(0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b);
    
    // record block for deposit transaction
    mapping(address => uint) internal depositedBlock;
    // treasury fee
    uint public yieldFeePerc;
    address public treasury;
    // peng together contract for deposit/withdraw record purpose
    IRecord public record;
    // peng together contract for receive eth on ethereum
    address public reward;
    address public admin;
    // accumulate weth yield after fee
    uint public accWethYield;
    // peng together helper contract for interact with this contract
    address public helper;

    event Deposit(address indexed user, uint amount, uint lpTokenAmt);
    event Withdraw(address indexed user, uint amount, uint lpTokenAmt, uint actualAmt);
    event Harvest(uint crvAmt, uint opAmt, uint wethAmt, uint fee);
    // event SetAdmin(address admin);
    // event SetTreasury(address treasury_);
    // event SetReward(address reward_);
    // event SetYieldFeePerc(uint yieldFeePerc_);
    // event SetHelper(address helper_);
    // event UnwrapAndBridge(uint wethAmt, uint bridgeGasFee);
    event Migrate(uint lpTokenWithdraw);

    // function initialize(IRecord record_) external virtual initializer {
    //     require(record_ != IRecord(address(0)), "0 address");
    //     __Ownable_init();

    //     admin = msg.sender;
    //     treasury = msg.sender;
    //     yieldFeePerc = 1000; // 10%
    //     record = record_;

    //     USDC.safeApprove(address(ZAP), type(uint).max);
    //     LP_TOKEN.safeApprove(address(GAUGE), type(uint).max);
    //     LP_TOKEN.safeApprove(address(ZAP), type(uint).max);
    //     CRV.safeApprove(address(SWAP_ROUTER), type(uint).max);
    //     OP.safeApprove(address(SWAP_ROUTER), type(uint).max);
    // }

    /// @notice deposit funds into peng together
    /// @param token token deposit
    /// @param amount amount deposit
    /// @param amountOutMin minimum lp token receive when deposit amount of token
    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external payable virtual {
        _deposit(token, amount, amountOutMin, msg.sender);
    }

    // /// @notice deposit funds into peng together by helper, only can call by helper
    // /// @param token token deposit
    // /// @param amount amount deposit
    // /// @param amountOutMin minimum lp token receive after add liquidity into curve pool
    // /// @param depositor account deposit
    // function depositByHelper(
    //     IERC20Upgradeable token,
    //     uint amount,
    //     uint amountOutMin,
    //     address depositor
    // ) external payable virtual {
    //     require(msg.sender == helper, "helper only");

    //     _deposit(token, amount, amountOutMin, depositor);
    // }

    function _deposit(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address depositor
    ) internal virtual nonReentrant whenNotPaused {
        require(token == USDC, "usdc only");
        require(amount >= 100e6, "min $100");

        // save block which call this function to check if withdraw within same block
        depositedBlock[depositor] = block.number;

        USDC.safeTransferFrom(msg.sender, address(this), amount);

        uint[4] memory amounts; // [susd, usdt, usdc, dai]
        amounts[2] = amount;
        // zap add liquidity by convert usdc -> 3crv then add liquidity into susd/3crv pool to get lp token
        uint lpTokenAmt = ZAP.add_liquidity(address(POOL), amounts, amountOutMin);
        // deposit into curve lp token staking pool for reward
        GAUGE.deposit(lpTokenAmt);

        // update user info into peng together record contract
        record.updateUser(true, depositor, amount, lpTokenAmt);

        emit Deposit(depositor, amount, lpTokenAmt);
    }

    /// @notice withdraw funds from peng together
    /// @param token token withdraw
    /// @param amount amount withdraw
    /// @param amountOutMin minimum token received after remove liquidity from curve pool
    /// @return actualAmt actual amount withdrawal, might not same as amount withdraw due to
    /// trading fee & slippage
    function withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin
    ) external virtual returns (uint actualAmt) {
        actualAmt = _withdraw(token, amount, amountOutMin, msg.sender);
    }

    // /// @notice withdraw funds from peng together by helper, only can call by helper
    // /// @param account account withdrawal
    // function withdrawByHelper(
    //     IERC20Upgradeable token,
    //     uint amount,
    //     uint amountOutMin,
    //     address account
    // ) external virtual returns (uint actualAmt) {
    //     require(msg.sender == helper, "helper only");

    //     actualAmt = _withdraw(token, amount, amountOutMin, account);
    // }

    function _withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        address account
    ) internal virtual nonReentrant returns (uint actualAmt) {
        require(token == USDC, "usdc only");
        // fetch deposit balance & lp token balance from record contract
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(account);
        require(depositBal >= amount, "amount > depositBal");
        require(depositedBlock[account] != block.number, "same block deposit withdraw");

        // calculate lp token amount to withdraw
        uint lpTokenAmt = lpTokenBal * amount / depositBal;
        // withdraw from curve lp token staking pool
        GAUGE.withdraw(lpTokenAmt);
        // burn lp token and remove liquidity via zap contract, lp token -> 3crv -> usdc
        actualAmt = ZAP.remove_liquidity_one_coin(address(POOL), lpTokenAmt, 2, amountOutMin);

        // update user info into peng together record contract
        record.updateUser(false, account, amount, lpTokenAmt);

        // token transfer to msg.sender instead of account because
        // for withdraw() token transfer to caller (depositor)
        // for withdrawByHelper() token transfer to pengHelperOp
        // and pengHelperOp help to transfer token to account
        USDC.safeTransfer(msg.sender, actualAmt);

        emit Withdraw(account, amount, lpTokenAmt, actualAmt);
    }

    /// @notice harvest from curve for rewards and sell them for weth
    function harvest() external virtual {
        MINTER.mint(address(GAUGE)); // to claim crv
        GAUGE.claim_rewards(); // to claim op
        uint wethAmt = 0;

        // swap crv to weth via uniswap v3
        // no slippage needed because small amount swap
        uint crvAmt = CRV.balanceOf(address(this));
        // if (crvAmt > 1 ether) { // minimum swap 1e18 crv
            wethAmt = SWAP_ROUTER.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(CRV),
                    tokenOut: address(WETH),
                    fee: 3000, // 0.3%
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: crvAmt,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        // }

        // swap op to weth via uniswap v3
        // no slippage needed because small amount swap
        uint opAmt = OP.balanceOf(address(this));
        // if (opAmt > 1 ether) { // minimum swap 1e18 op
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
        // }

        // collect fee
        uint fee = wethAmt * yieldFeePerc / 10000;
        wethAmt -= fee;
        WETH.safeTransfer(treasury, fee);

        // add up accumulate weth yield after fee
        accWethYield += wethAmt;

        emit Harvest(crvAmt, opAmt, wethAmt, fee);
    }

    // /// @notice unwrap weth and bridge to ethereum reward contract via stargate
    // /// @dev need provide msg.value for gas fee for transfer eth from stargate to reward contract on ethereum
    // function unwrapAndBridge() external payable {
    //     require(msg.sender == admin || msg.sender == owner(), "only admin or owner");
    //     uint bridgeGasFee = msg.value;

    //     // unwrap weth to native eth as stargate only accept native eth
    //     uint wethAmt = WETH.balanceOf(address(this));
    //     WETH.withdraw(wethAmt);

    //     // bridge eth to ethereum
    //     STARGATE_ROUTER_ETH.swapETH{value: bridgeGasFee + wethAmt}(
    //         101, // _dstChainId, ethereum
    //         admin, // _refundAddress, if actual bridgeGasFee is less than msg.value 
    //         abi.encodePacked(reward), // _toAddress, reward contract on ethereum
    //         wethAmt, // _amountLD, amount to bridge
    //         wethAmt * 995 / 1000 // _minAmountLD, minimum eth receive on ethereum, 0.5% slippage
    //     );

    //     emit UnwrapAndBridge(wethAmt, bridgeGasFee);
    // }

    /// @notice able to receive eth on this contract
    receive() external payable {}

    /// @notice pause deposit, only callable by owner
    function pauseContract() external onlyOwner {
        _pause();
    }

    // /// @notice unpause deposit, only callable by owner
    // function unPauseContract() external onlyOwner {
    //     _unpause();
    // }

    // /// @notice set new admin, only callable by owner
    // /// @param admin_ new admin address
    // function setAdmin(address admin_) external onlyOwner {
    //     require(admin_ != address(0), "0 address");
    //     admin = admin_;

    //     emit SetAdmin(admin_);
    // }

    // /// @notice set new treasury, only callable by owner
    // /// @param treasury_ new treasury address
    // function setTreasury(address treasury_) external onlyOwner {
    //     require(treasury_ != address(0), "0 address");
    //     treasury = treasury_;

    //     emit SetTreasury(treasury_);
    // }

    // /// @notice set new reward contract, only callable by owner
    // /// @param reward_ new reward contract address
    // function setReward(address reward_) external onlyOwner {
    //     require(reward_ != address(0), "0 address");
    //     reward = reward_;

    //     emit SetReward(reward_);
    // }

    // /// @notice set new yield fee percentage, dominance in 10000, only callable by owner
    // /// @param yieldFeePerc_ new yield fee percentage
    // function setYieldFeePerc(uint yieldFeePerc_) external onlyOwner {
    //     // yieldFeePerc cannot be more than 30%
    //     require(yieldFeePerc_ < 3000, "yieldFeePerc > 3000");
    //     yieldFeePerc = yieldFeePerc_;

    //     emit SetYieldFeePerc(yieldFeePerc_);
    // }

    // /// @notice set new helper contract, only callable by owner
    // /// @param helper_ new helper contract address
    // function setHelper(address helper_) external onlyOwner {
    //     require(helper_ != address(0), "0 address");
    //     helper = helper_;

    //     emit SetHelper(helper_);
    // }

    /// @notice calculate usd value per lp token
    function getPricePerFullShareInUSD() public virtual view returns (uint) {
        return POOL.get_virtual_price() / 1e12; // 6 decimals
    }

    /// @notice get all lp token amount stake in curve farm(gauge)
    function getAllPool() public virtual view returns (uint) {
        return GAUGE.balanceOf(address(this)); // 18 decimals
    }

    /// @notice get all lp token amount stake in curve farm(gauge)
    /// @return allPoolInUSD all lp token amount in usd value
    function getAllPoolInUSD() external virtual view returns (uint allPoolInUSD) {
        uint allPool = getAllPool();
        if (allPool > 0) {
            allPoolInUSD = allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
        }
    }

    /// @notice get current pending rewards for harvest
    /// @dev Call this function off-chain by using view
    /// @return crvReward pendig crv reward
    /// @return opReward pendig op reward
    function getPoolPendingReward() external virtual returns (uint crvReward, uint opReward) {
        crvReward = GAUGE.claimable_tokens(address(this));
        opReward = GAUGE.claimable_reward(address(this), address(OP));
    }

    /// @notice get user exact deposit balance (without slippage after deposit into curve pool)
    /// @param account user address
    /// @return depositBal user exact deposit balance, 6 decimals for usd, 18 decimals for eth
    function getUserDepositBalance(address account) external view returns (uint depositBal) {
        (depositBal,,,) = record.userInfo(account);
    }

    /// @notice user lp token balance after deposit into curve farm
    /// @param account user address
    /// @return lpTokenBal user lp token balance
    function getUserBalance(address account) external view returns (uint lpTokenBal) {
        (, lpTokenBal,,) = record.userInfo(account); // 18 decimals
    }

    /// @notice user actual balance in usd after deposit into farm (after slippage)
    /// @param account user address
    function getUserBalanceInUSD(address account) external virtual view returns (uint) {
        (, uint lpTokenBal,,) = record.userInfo(account);
        return lpTokenBal * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    /// @dev for uups upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function migrate(address account) external onlyOwner {
        // fetch deposit balance & lp token balance from record contract
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(account);
        // update user info into peng together record contract
        record.updateUser(false, account, depositBal, lpTokenBal);

        // approve susd/3crv vault reward in weth to transfer out gauge token
        IVault vault = IVault(0xA8e39872452BA48b1F4c7e16b78668199d2C41Dd); // susd/3crv reward in weth
        IERC20Upgradeable(address(GAUGE)).approve(address(vault), lpTokenBal);

        // record into susd/3crv vault reward in weth
        vault.depositOnBehalf(lpTokenBal, account);

        emit Migrate(lpTokenBal);
    }

    // distribute weth pro-rated calculated off-chain to current depositors
    // at the moment of twitter announcement
    function distribute(address[] memory accounts, uint[] memory amounts) external onlyOwner {
        for (uint i; i < accounts.length; i++) {
            address account = accounts[i];
            uint amount = amounts[i];
            WETH.transfer(account, amount);
        }
    }

    // sweep balance reward token to multisig
    function sweep() external onlyOwner {
        address multisig = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
        WETH.transfer(multisig, WETH.balanceOf(address(this)));
        OP.transfer(multisig, OP.balanceOf(address(this)));
        CRV.transfer(multisig, CRV.balanceOf(address(this)));
    }
}
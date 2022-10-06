// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
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
import "../interface/IStargateRouterETH.sol";

contract PengTogether is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {

    IERC20Upgradeable constant usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable constant op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IWETH constant weth = IWETH(0x4200000000000000000000000000000000000006);
    IPool constant pool = IPool(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable constant lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IZap constant zap = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    IGauge constant gauge = IGauge(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
    IMinter constant minter = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IStargateRouterETH constant stargateRouterETH = IStargateRouterETH(0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b);
    mapping(address => uint) internal depositedBlock;
    uint public yieldFeePerc;
    address public treasury;
    IRecord public record;
    address public reward; // on ethereum
    address public admin;
    uint public accWethYield;

    event Deposit(address indexed user, uint amount, uint lpTokenAmt);
    event Withdraw(address indexed user, uint amount, uint lpTokenAmt, uint actualAmt);
    event Harvest(uint crvAmt, uint opAmt, uint wethAmt, uint fee);
    event SetAdmin(address admin);
    event SetTreasury(address _treasury);
    event SetReward(address _reward);
    event SetYieldFeePerc(uint _yieldFeePerc);

    function initialize(IRecord _record) external virtual initializer {
        __Ownable_init();

        admin = msg.sender;
        treasury = msg.sender;
        yieldFeePerc = 1000;
        record = _record;

        usdc.approve(address(zap), type(uint).max);
        lpToken.approve(address(gauge), type(uint).max);
        lpToken.approve(address(zap), type(uint).max);
        crv.approve(address(swapRouter), type(uint).max);
        op.approve(address(swapRouter), type(uint).max);
    }

    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable virtual nonReentrant whenNotPaused {
        require(token == usdc, "usdc only");
        require(amount >= 100e6, "min $100");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint[4] memory amounts;
        amounts[2] = amount;
        uint lpTokenAmt = zap.add_liquidity(address(pool), amounts, amountOutMin);
        gauge.deposit(lpTokenAmt);

        record.updateUser(true, msg.sender, amount, lpTokenAmt);
        depositedBlock[msg.sender] = block.number;

        emit Deposit(msg.sender, amount, lpTokenAmt);
    }

    function withdraw(IERC20Upgradeable token, uint amount, uint amountOutMin) external virtual nonReentrant {
        require(token == usdc, "usdc only");
        (uint depositBal, uint lpTokenBal,,) = record.userInfo(msg.sender);
        require(depositBal >= amount, "amount > depositBal");
        require(depositedBlock[msg.sender] != block.number, "same block deposit withdraw");

        uint withdrawPerc = amount * 1e18 / depositBal;
        uint lpTokenAmt = lpTokenBal * withdrawPerc / 1e18;
        gauge.withdraw(lpTokenAmt);
        uint actualAmt = zap.remove_liquidity_one_coin(address(pool), lpTokenAmt, 2, amountOutMin);

        record.updateUser(false, msg.sender, amount, lpTokenAmt);

        usdc.transfer(msg.sender, actualAmt);
        emit Withdraw(msg.sender, amount, lpTokenAmt, actualAmt);
    }

    function harvest() external virtual {
        minter.mint(address(gauge)); // to claim crv
        gauge.claim_rewards(); // to claim op
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

    function unwrapAndBridge() external payable {
        require(msg.sender == admin || msg.sender == owner(), "only admin or owner");

        // unwrap weth to native eth
        uint wethAmt = weth.balanceOf(address(this));
        weth.withdraw(wethAmt);

        // bridge eth to ethereum
        stargateRouterETH.swapETH{value: msg.value + wethAmt}(
            101, // _dstChainId
            admin, // _refundAddress
            abi.encodePacked(reward), // _toAddress
            wethAmt, // _amountLD
            wethAmt * 995 / 1000 // _minAmountLD, 0.5% slippage
        );
    }

    receive() external payable {}

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;

        emit SetTreasury(_treasury);
    }

    function setReward(address _reward) external onlyOwner {
        reward = _reward;

        emit SetReward(_reward);
    }

    function setYieldFeePerc(uint _yieldFeePerc) external onlyOwner {
        require(_yieldFeePerc < 3000, "yieldFeePerc > 3000");
        yieldFeePerc = _yieldFeePerc;

        emit SetYieldFeePerc(_yieldFeePerc);
    }

    function setAccWethYield(uint _accWethYield) external onlyOwner {
        accWethYield = _accWethYield;
    }

    function getPricePerFullShareInUSD() public virtual view returns (uint) {
        return pool.get_virtual_price() / 1e12; // 6 decimals
    }

    function getAllPool() public virtual view returns (uint) {
        return gauge.balanceOf(address(this)); // lpToken, 18 decimals
    }

    function getAllPoolInUSD() external view returns (uint) {
        uint allPool = getAllPool();
        if (allPool == 0) return 0;
        return allPool * getPricePerFullShareInUSD() / 1e18; // 6 decimals
    }

    /// @dev Call this function off-chain by using view
    function getPoolPendingReward() external returns (uint crvReward, uint opReward) {
        crvReward = gauge.claimable_tokens(address(this));
        opReward = gauge.claimable_reward(address(this), address(op));
    }

    ///@notice user deposit balance without slippage
    function getUserDepositBalance(address account) external view returns (uint depositBal) {
        // return userInfo[account].depositBal;
        (depositBal,,,) = record.userInfo(account);
    }

    ///@notice user lpToken balance after deposit into farm, 18 decimals
    function getUserBalance(address account) external view returns (uint lpTokenBal) {
        (, lpTokenBal,,) = record.userInfo(account);
    }

    ///@notice user actual balance in usd after deposit into farm (after slippage), 6 decimals
    function getUserBalanceInUSD(address account) external view returns (uint) {
        (, uint lpTokenBal,,) = record.userInfo(account);
        return lpTokenBal * getPricePerFullShareInUSD() / 1e18;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
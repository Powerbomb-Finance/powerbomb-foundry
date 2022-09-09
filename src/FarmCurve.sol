// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IZap.sol";
import "../interface/IMinter.sol";
import "../interface/IPool.sol";
import "../interface/IGauge.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IStargateRouterETH.sol";
import "../interface/IWETH.sol";

contract FarmCurve is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    IERC20Upgradeable constant usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable constant op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IWETH constant weth = IWETH(0x4200000000000000000000000000000000000006);
    IPool constant pool = IPool(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable constant lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IZap constant zap = IZap(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    IMinter constant minter = IMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    IGauge constant gauge = IGauge(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IStargateRouterETH constant stargateRouterETH = IStargateRouterETH(0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b);
    address public admin;
    address public vault;
    address public reward;
    address public treasury; // pending usage

    event Harvest(uint crvAmt, uint opAmt, uint wethAmt);
    event SetAdmin(address admin);
    event SetVault(address vault);
    event SetReward(address reward);

    modifier onlyVault {
        require(msg.sender == address(vault), "only vault");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();

        admin = msg.sender;

        usdc.approve(address(zap), type(uint).max);
        lpToken.approve(address(gauge), type(uint).max);
        lpToken.approve(address(zap), type(uint).max);
        crv.approve(address(swapRouter), type(uint).max);
        op.approve(address(swapRouter), type(uint).max);
    }

    function deposit(uint amount, uint amountOutMin) external onlyVault returns (uint lpTokenAmt) {
        usdc.transferFrom(msg.sender, address(this), amount);

        uint[4] memory amounts;
        amounts[2] = amount;
        lpTokenAmt = zap.add_liquidity(address(pool), amounts, amountOutMin);
        gauge.deposit(lpTokenAmt);
    }

    function withdraw(uint lpTokenAmt, uint amountOutMin) external onlyVault returns (uint amountOut) {
        gauge.withdraw(lpTokenAmt);
        amountOut = zap.remove_liquidity_one_coin(address(pool), lpTokenAmt, 2, amountOutMin);

        usdc.transfer(msg.sender, amountOut);
    }

    function harvest() external payable {
        require(msg.sender == admin, "only admin");

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

        weth.withdraw(wethAmt);

        // bridge eth to ethereum
        stargateRouterETH.swapETH{value: msg.value + wethAmt}(
            1, // _dstChainId
            admin, // _refundAddress
            abi.encodePacked(reward), // _toAddress
            wethAmt, // _amountLD
            wethAmt * 995 / 1000 // _minAmountLD, 0.5% slippage
        );

        emit Harvest(crvAmt, opAmt, wethAmt);
    }

    receive() external payable {}

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;

        emit SetVault(_vault);
    }

    function setReward(address _reward) external onlyOwner {
        reward = _reward;

        emit SetReward(_reward);
    }

    function getPricePerFullShareInUSD() public view returns (uint) {
        return pool.get_virtual_price() / 1e12; // 6 decimals
    }

    function getAllPool() public view returns (uint) {
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

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

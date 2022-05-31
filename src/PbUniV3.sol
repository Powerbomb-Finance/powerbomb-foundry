// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/INonfungiblePositionManager.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IReward.sol";
import "../libraries/TickMath.sol";

import "forge-std/Test.sol";

contract PbUniV3 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    INonfungiblePositionManager public constant nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;
    uint24 public poolFee; // 3000 = 0.3%
    IReward public reward;
    uint public tokenId;
    address public bot;

    event Deposit(address indexed account, uint amount, address indexed rewardToken);
    event Reinvest(address indexed token0, address indexed token1, uint amount, uint liquidity);
    event AddLiquidity(uint amount0, uint amount1, uint liquidity);

    modifier onlyEOA {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    modifier onlyAuthorized {
        require(msg.sender == bot || msg.sender == owner(), "Only authorized");
        _;
    }

    function initialize(
        IERC20Upgradeable _token0,
        IERC20Upgradeable _token1,
        uint24 _poolFee,
        address _bot,
        IReward _reward
    ) external initializer {
        __Ownable_init();

        token0 = _token0;
        token1 = _token1;
        poolFee = _poolFee;
        bot = _bot;
        reward = _reward;

        token0.safeApprove(address(swapRouter), type(uint).max);
        token0.safeApprove(address(nonfungiblePositionManager), type(uint).max);
        token0.safeApprove(address(reward), type(uint).max);
        token1.safeApprove(address(swapRouter), type(uint).max);
        token1.safeApprove(address(nonfungiblePositionManager), type(uint).max);
        token1.safeApprove(address(reward), type(uint).max);
    }

    function deposit(
        uint amount,
        uint amountOutMin,
        uint slippage,
        int24 tickLower,
        int24 tickUpper,
        address rewardToken
    ) external nonReentrant whenNotPaused {
        USDC.safeTransferFrom(msg.sender, address(this), amount);

        // Swap USDC to pair tokens
        if (token0 == USDC) {
            _swap(address(USDC), address(token1), amount / 2, amountOutMin);
        } else if (token1 == USDC) {
            _swap(address(USDC), address(token0), amount / 2, amountOutMin);
        } else {
            _swap(address(USDC), address(token0), amount / 2, amountOutMin);
            _swap(address(USDC), address(token1), amount / 2, amountOutMin);
        }

        // Get tokens amount & minimum amount add into liquidity
        uint token0Amt = token0.balanceOf(address(this));
        uint token0AmtMin = token0Amt * (10000 - slippage) / 10000;
        uint token1Amt = token1.balanceOf(address(this));
        uint token1AmtMin = token1Amt * (10000 - slippage) / 10000;

        if (tokenId != 0) {
            // Already mint the NFT
            _addLiquidity(token0Amt, token1Amt, token0AmtMin, token1AmtMin);
        } else {
            // First time add liquidity (mint the NFT)
            _mint(tickLower, tickUpper, token0Amt, token1Amt, token0AmtMin, token1AmtMin);
        }

        // Record into reward contract
        reward.recordDeposit(msg.sender, amount, rewardToken);
        emit Deposit(msg.sender, amount, rewardToken);
    }

    /// @notice This function is to add back tokens that left by last liquidity adding
    /// @param tokenIn token that have balance in contract (which will swap half amount to pair token)
    function reinvest(IERC20Upgradeable tokenIn, uint amount, uint amountOutMin, uint slippage) external onlyAuthorized {
        // Determine pair token and swap half amount into pair token
        IERC20Upgradeable tokenOut = tokenIn == token0 ? token1 : token0;
        _swap(address(tokenIn), address(tokenOut), amount / 2, amountOutMin);

        // Get tokens amount & minimum amount add into liquidity
        uint token0Amt = token0.balanceOf(address(this));
        uint token0AmtMin = token0Amt * (10000 - slippage) / 10000;
        uint token1Amt = token1.balanceOf(address(this));
        uint token1AmtMin = token1Amt * (10000 - slippage) / 10000;

        // Add liquidity
        uint liquidity = _addLiquidity(token0Amt, token1Amt, token0AmtMin, token1AmtMin);
        emit Reinvest(address(tokenIn), address(tokenOut), amount, liquidity);
    }

    function withdraw(uint amount, address rewardToken, uint amount0Min, uint amount1Min, uint amountOutMin) external {
        // Calculate liquidity to withdraw
        uint allPool = reward.getAllPool();
        uint withdrawPerc = amount * 10000 / allPool;
        (,,,,,,,uint liquidity ,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint withdrawLiquidity = liquidity * withdrawPerc / 10000;

        reward.recordWithdraw(msg.sender, amount, rewardToken);

        (uint amount0, uint amount1) = _removeLiquidity(uint128(withdrawLiquidity), amount0Min, amount1Min);
        (uint token0Amt, uint token1Amt) = _collect(uint128(amount0), uint128(amount1));

        uint USDCAmt;
        if (token0 == USDC) {
            USDCAmt = token0Amt;
            USDCAmt += _swap(address(token1), address(USDC), token1Amt, amountOutMin);
        } else if (token1 == USDC) {
            USDCAmt = token1Amt;
            USDCAmt += _swap(address(token0), address(USDC), token0Amt, amountOutMin);
        } else {
            USDCAmt = _swap(address(token0), address(USDC), token0Amt, amountOutMin);
            USDCAmt += _swap(address(token1), address(USDC), token1Amt, amountOutMin);
        }

        USDC.safeTransfer(msg.sender, USDCAmt);
    }

    function harvest() external {
        (uint amount0, uint amount1) = _collect(type(uint128).max, type(uint128).max);
        reward.harvest(address(token0), address(token1), amount0, amount1);
    }

    function claim() external {
        reward.claim(msg.sender);
    }

    function _collect(uint128 amount0, uint128 amount1) private returns (uint amt0Collected, uint amt1Collected) {
        INonfungiblePositionManager.CollectParams memory collectParams =
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: amount0,
                amount1Max: amount1
            });
        (amt0Collected, amt1Collected) =  nonfungiblePositionManager.collect(collectParams);
    }

    function updateTicks(int24 tickLower, int24 tickUpper, uint amount0Min, uint amount1Min, uint slippage) external onlyAuthorized {
        (,,,,,,,uint128 liquidity ,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint amount0, uint amount1) = _removeLiquidity(liquidity, amount0Min, amount1Min);
        _collect(uint128(amount0), uint128(amount1));
        uint token0Amt = token0.balanceOf(address(this));
        uint token0AmtMin = token0Amt * (10000 - slippage) / 10000;
        uint token1Amt = token1.balanceOf(address(this));
        uint token1AmtMin = token1Amt * (10000 - slippage) / 10000;
        _mint(tickLower, tickUpper, token0Amt, token1Amt, token0AmtMin, token1AmtMin);
    }

    function _swap(address tokenIn, address tokenOut, uint amount, uint amountOutMin) private returns (uint) {
        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
        return swapRouter.exactInputSingle(params);
    }

    function _addLiquidity(uint token0Amt, uint token1Amt, uint token0AmtMin, uint token1AmtMin) private returns (uint liquidity) {
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: token0Amt,
                    amount1Desired: token1Amt,
                    amount0Min: token0AmtMin,
                    amount1Min: token1AmtMin,
                    deadline: block.timestamp
                });
        (liquidity,,) = nonfungiblePositionManager.increaseLiquidity(params);
        emit AddLiquidity(token0Amt, token1Amt, liquidity);
    }

    function _removeLiquidity(uint128 liquidity, uint amount0Min, uint amount1Min) private returns (uint amount0, uint amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = 
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            });
        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
    }

    function _mint(
        int24 tickLower,
        int24 tickUpper,
        uint token0Amt,
        uint token1Amt,
        uint token0AmtMin,
        uint token1AmtMin
    ) private {
        INonfungiblePositionManager.MintParams memory params =
                INonfungiblePositionManager.MintParams({
                    token0: address(token0),
                    token1: address(token1),
                    fee: poolFee,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: token0Amt,
                    amount1Desired: token1Amt,
                    amount0Min: token0AmtMin,
                    amount1Min: token1AmtMin,
                    recipient: address(this),
                    deadline: block.timestamp
                });
            (uint _tokenId,,,) = nonfungiblePositionManager.mint(params);
            tokenId = _tokenId;
    }

    function setReward(IReward _reward) external onlyOwner {
        reward = _reward;
    }

    function getTicks(uint160 sqrtPriceX96Lower, uint160 sqrtPriceX96Upper) external pure returns (int24[] memory ticks) {
        ticks = new int24[](2);
        ticks[0] = TickMath.getTickAtSqrtRatio(sqrtPriceX96Lower);
        ticks[1] = TickMath.getTickAtSqrtRatio(sqrtPriceX96Upper);
    }

    function getUserBalance(address account, address rewardToken) external view returns (uint) {
        return reward.userInfo(rewardToken, account);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/INonfungiblePositionManager.sol";
import "../interface/IUniswapV3Pool.sol";
import "../interface/ISwapRouter.sol";
import "../interface/IReward.sol";
import "../libraries/TickMath.sol";
import "../libraries/LiquidityAmounts.sol";

contract PbUniV3 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    INonfungiblePositionManager public constant nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;
    IUniswapV3Pool public uniswapV3Pool;
    uint24 public poolFee; // 3000 = 0.3%
    IReward public reward;
    uint public tokenId;
    address public bot;

    event Deposit(address indexed account, uint amount, address indexed rewardToken);
    event Reinvest(address indexed token0, address indexed token1, uint amount, uint liquidity);
    event AddLiquidity(uint amount0, uint amount1, uint liquidity);
    event RemoveLiquidity(uint amount0, uint amount1, uint liquidity);
    event UpdateTicks(int24 tickLower, int24 tickUpper);
    event ChangeTokenId(uint oldTokenId, uint newTokenId);
    event SetReward(address oldReward, address newReward);
    event SetBot(address oldBot, address newBot);

    modifier onlyEOA {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    modifier onlyAuthorized {
        require(msg.sender == bot || msg.sender == owner(), "Only authorized");
        _;
    }

    function initialize(IUniswapV3Pool _uniswapV3Pool, address _bot) external initializer {
        __Ownable_init();

        uniswapV3Pool = _uniswapV3Pool;
        token0 = IERC20Upgradeable(uniswapV3Pool.token0());
        token1 = IERC20Upgradeable(uniswapV3Pool.token1());
        poolFee = uniswapV3Pool.fee();
        bot = _bot;

        token0.safeApprove(address(swapRouter), type(uint).max);
        token0.safeApprove(address(nonfungiblePositionManager), type(uint).max);
        token1.safeApprove(address(swapRouter), type(uint).max);
        token1.safeApprove(address(nonfungiblePositionManager), type(uint).max);

        if (USDC != token0 && USDC != token1) {
            USDC.safeApprove(address(swapRouter), type(uint).max);
        }
    }

    /// @notice Deposit with USDC
    function deposit(
        uint amount,
        uint[] calldata amountsOutMin,
        uint slippage,
        int24 tickLower,
        int24 tickUpper,
        address rewardToken
    ) external onlyEOA nonReentrant whenNotPaused {
        // Do harvest first before deposit to prevent yield sandwich attack
        if (tokenId != 0) harvest();

        USDC.safeTransferFrom(msg.sender, address(this), amount);

        // Swap USDC to pair tokens
        if (token0 == USDC) {
            _swap(address(USDC), address(token1), amount / 2, amountsOutMin[0]);
        } else if (token1 == USDC) {
            _swap(address(USDC), address(token0), amount / 2, amountsOutMin[0]);
        } else {
            _swap(address(USDC), address(token0), amount / 2, amountsOutMin[0]);
            _swap(address(USDC), address(token1), amount / 2, amountsOutMin[1]);
        }

        // Get tokens amount & minimum amount add into liquidity
        uint token0Amt = token0.balanceOf(address(this));
        uint token0AmtMin = token0Amt * (10000 - slippage) / 10000;
        uint token1Amt = token1.balanceOf(address(this));
        uint token1AmtMin = token1Amt * (10000 - slippage) / 10000;

        // Add liquidity
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

    /// @notice Withdraw out USDC
    function withdraw(
        uint amount,
        address rewardToken,
        uint amount0Min,
        uint amount1Min,
        uint[] calldata amountsOutMin
    ) external onlyEOA nonReentrant {
        // Calculate liquidity to withdraw
        uint allPool = reward.getAllPool();
        uint withdrawPerc = amount * 10000 / allPool;
        (,,,,,,,uint liquidity ,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint withdrawLiquidity = liquidity * withdrawPerc / 10000;

        // Record into reward contract
        reward.recordWithdraw(msg.sender, amount, rewardToken);

        // Remove liquidity & collect (Uniswap v3 mechanism)
        (uint amount0, uint amount1) = _removeLiquidity(uint128(withdrawLiquidity), amount0Min, amount1Min);
        (uint token0Amt, uint token1Amt) = _collect(uint128(amount0), uint128(amount1));

        // Swap any non-USDC token to USDC
        uint USDCAmt;
        if (token0 == USDC) {
            USDCAmt = token0Amt;
            USDCAmt += _swap(address(token1), address(USDC), token1Amt, amountsOutMin[0]);
        } else if (token1 == USDC) {
            USDCAmt = token1Amt;
            USDCAmt += _swap(address(token0), address(USDC), token0Amt, amountsOutMin[0]);
        } else {
            USDCAmt = _swap(address(token0), address(USDC), token0Amt, amountsOutMin[0]);
            USDCAmt += _swap(address(token1), address(USDC), token1Amt, amountsOutMin[1]);
        }

        // Transfer to user
        USDC.safeTransfer(msg.sender, USDCAmt);
    }

    function harvest() public {
        // Uniswap v3 mechanism: collect fees by pass in max uint
        (uint amount0, uint amount1) = _collect(type(uint128).max, type(uint128).max);
        // Transfer tokens to reward contract for swap into rewardToken
        if (amount0 > 0 || amount1 > 0) {
            reward.harvest(amount0, amount1);
        }
    }

    function claimReward() external onlyEOA nonReentrant {
        // Harvest first to provide user updated reward
        harvest();
        // Claim rewardToken on reward contract
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

    /// @notice Function to change price range: remove liquidity
    function updateTicks(int24 tickLower, int24 tickUpper, uint amount0Min, uint amount1Min, uint slippage) external onlyAuthorized {
        // Harvest any unclaimed fees
        harvest();

        // Remove all liquidity
        (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint amount0, uint amount1) = _removeLiquidity(liquidity, amount0Min, amount1Min);
        _collect(uint128(amount0), uint128(amount1));

        // Burn the NFT
        nonfungiblePositionManager.burn(tokenId);

        // Get tokens amount & minimum amount add into liquidity
        uint token0Amt = token0.balanceOf(address(this));
        uint token0AmtMin = token0Amt * (10000 - slippage) / 10000;
        uint token1Amt = token1.balanceOf(address(this));
        uint token1AmtMin = token1Amt * (10000 - slippage) / 10000;

        // Mint new NFT with new ticks
        _mint(tickLower, tickUpper, token0Amt, token1Amt, token0AmtMin, token1AmtMin);
        emit UpdateTicks(tickLower, tickUpper);
    }

    /// @notice Swap fee hardcode to 0.05%
    function _swap(address tokenIn, address tokenOut, uint amountIn, uint amountOutMin) private returns (uint amountOut) {
        if (amountIn == 0) return 0;

        if (tokenOut == address(WBTC) && tokenIn != address(WETH)) {
            // The only good liquidity swap to WBTC is WETH-WBTC in Arbitrum, so all tokens swap to WETH need route through WETH
            ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: abi.encodePacked(address(tokenIn), uint24(500), address(WETH), uint24(500), address(WBTC)),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin
                });
            amountOut = swapRouter.exactInput(params);

        } else if (tokenIn == address(WBTC) && tokenOut != address(WETH)) {
            // Reverse of if above
             ISwapRouter.ExactInputParams memory params = 
                ISwapRouter.ExactInputParams({
                    path: abi.encodePacked(address(WBTC), uint24(500), address(WETH), uint24(500), address(tokenOut)),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin
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
                    amountOutMinimum: amountOutMin,
                    sqrtPriceLimitX96: 0
                });
            amountOut = swapRouter.exactInputSingle(params);
        }
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
        emit RemoveLiquidity(amount0, amount1, uint(liquidity));
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
            // Update tokenId
            emit ChangeTokenId(tokenId, _tokenId);
            tokenId = _tokenId;
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    function setReward(IReward _reward) external onlyOwner {
        emit SetReward(address(reward), address(_reward));
        reward = _reward;
        token0.safeApprove(address(reward), type(uint).max);
        token1.safeApprove(address(reward), type(uint).max);
    }

    function setBot(address _bot) external onlyOwner {
        emit SetBot(bot, _bot);
        bot = _bot;
    }

    function getTicks(uint160 sqrtPriceX96Lower, uint160 sqrtPriceX96Upper) external pure returns (int24 tickLower, int24 tickUpper) {
        tickLower = TickMath.getTickAtSqrtRatio(sqrtPriceX96Lower);
        tickUpper = TickMath.getTickAtSqrtRatio(sqrtPriceX96Upper);
    }

    function getMinimumAmountsRemoveLiquidity(uint amount, uint slippage) external view returns (uint amount0Min, uint amount1Min) {
        (uint160 sqrtRatioX96,,,,,,) = uniswapV3Pool.slot0();
        (,,,,,int24 tickLower, int24 tickUpper, uint liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        uint allPool = reward.getAllPool();
        uint liquidity_ = liquidity * amount / allPool;
        (uint amount0, uint amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity_));
        amount0Min = amount0 * (10000 - slippage) / 10000;
        amount1Min = amount1 * (10000 - slippage) / 10000;
    }

    function getAllPool() external view returns (uint) {
        return reward.getAllPool();
    }

    function getUserBalance(address account, address rewardToken) external view returns (uint balance) {
        (balance,) = reward.userInfo(account, rewardToken);
    }

    function getUserPendingReward(address account, address rewardToken) external view returns (uint ibRewardTokenAmt) {
        (uint balance, uint rewardStartAt) = reward.userInfo(account, rewardToken);
        (uint accRewardPerlpToken,,,) = reward.rewardInfo(rewardToken);
        ibRewardTokenAmt = (balance * accRewardPerlpToken / 1e36) - rewardStartAt;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

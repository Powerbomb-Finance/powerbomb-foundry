// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/INonfungiblePositionManager.sol";
import "../interface/ISwapRouter.sol";
import "../libraries/TickMath.sol";

import "forge-std/Test.sol";

contract PbUniV3 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    INonfungiblePositionManager public constant nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint public tokenId;
    uint24 public poolFee; // 3000 = 0.3%
    address public bot;

    modifier onlyEOA {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    modifier onlyAuthorized {
        require(msg.sender == bot || msg.sender == owner(), "Only authorized");
        _;
    }

    function initialize(uint24 _poolFee, address _bot) external initializer {
        poolFee = _poolFee;
        bot = _bot;

        WETH.safeApprove(address(swapRouter), type(uint).max);
        WETH.safeApprove(address(nonfungiblePositionManager), type(uint).max);
        USDC.safeApprove(address(swapRouter), type(uint).max);
        USDC.safeApprove(address(nonfungiblePositionManager), type(uint).max);
    }

    function deposit(
        IERC20Upgradeable tokenIn,
        uint amount,
        uint amountOutMin,
        uint slippage,
        int24 tickLower,
        int24 tickUpper
    ) external nonReentrant whenNotPaused {
        tokenIn.safeTransferFrom(msg.sender, address(this), amount);

        IERC20Upgradeable tokenOut = tokenIn == WETH ? USDC : WETH;

        _swap(address(tokenIn), address(tokenOut), amount / 2, amountOutMin);

        uint WETHAmt = WETH.balanceOf(address(this));
        uint WETHAmtMin = WETHAmt * (10000 - slippage) / 10000;
        uint USDCAmt = USDC.balanceOf(address(this));
        uint USDCAmtMin = USDCAmt * (10000 - slippage) / 10000;
        // console.log(WETHAmt);
        // console.log(USDCAmt);

        if (tokenId != 0) {
            _addLiquidity(WETHAmt, USDCAmt, WETHAmtMin, USDCAmtMin);
        } else {
            _mint(tickLower, tickUpper, WETHAmt, USDCAmt, WETHAmtMin, USDCAmtMin);
        }
    }

    function reinvest(IERC20Upgradeable tokenIn, uint amount, uint amountOutMin, uint slippage) external onlyAuthorized {
        IERC20Upgradeable tokenOut = tokenIn == WETH ? USDC : WETH;
        _swap(address(tokenIn), address(tokenOut), amount / 2, amountOutMin);
        uint WETHAmt = WETH.balanceOf(address(this));
        uint WETHAmtMin = WETHAmt * (10000 - slippage) / 10000;
        uint USDCAmt = USDC.balanceOf(address(this));
        uint USDCAmtMin = USDCAmt * (10000 - slippage) / 10000;
        _addLiquidity(WETHAmt, USDCAmt, WETHAmtMin, USDCAmtMin);
    }

    function withdraw(IERC20Upgradeable token, uint128 liquidity, uint amount0Min, uint amount1Min, uint amountOutMin) external {
        (uint amount0, uint amount1) = _removeLiquidity(liquidity, amount0Min, amount1Min);
        (uint WETHAmt, uint USDCAmt) = _collect(uint128(amount0), uint128(amount1));
        // console.log(WETHAmt);
        // console.log(WETH.balanceOf(address(this)));
        // console.log(USDCAmt);
        // console.log(USDC.balanceOf(address(this)));

        if (token == USDC) {
            USDCAmt += _swap(address(WETH), address(USDC), WETHAmt, amountOutMin);
            USDC.safeTransfer(msg.sender, USDCAmt);
        } else { // token = WETH
            WETHAmt += _swap(address(USDC), address(WETH), USDCAmt, amountOutMin);
            WETH.safeTransfer(msg.sender, WETHAmt);
        }
    }

    function harvest() external {
        // INonfungiblePositionManager.CollectParams memory params =
        //     INonfungiblePositionManager.CollectParams({
        //         tokenId: tokenId,
        //         recipient: address(this),
        //         amount0Max: type(uint128).max,
        //         amount1Max: type(uint128).max
        //     });

        // (uint amount0, uint amount1) = nonfungiblePositionManager.collect(params);

        (uint amount0, uint amount1) = _collect(type(uint128).max, type(uint128).max);
        // console.log(amount0); // 125809921593
        // console.log(amount1); // 224
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
        // emit Collect(amt0Collected, amt1Collected);
    }

    function updateTicks(int24 tickLower, int24 tickUpper, uint amount0Min, uint amount1Min, uint slippage) external onlyAuthorized {
        (,,,,,,,uint128 liquidity ,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint amount0, uint amount1) = _removeLiquidity(liquidity, amount0Min, amount1Min);
        _collect(uint128(amount0), uint128(amount1));
        uint WETHAmt = WETH.balanceOf(address(this));
        uint WETHAmtMin = WETHAmt * (10000 - slippage) / 10000;
        uint USDCAmt = USDC.balanceOf(address(this));
        uint USDCAmtMin = USDCAmt * (10000 - slippage) / 10000;
        _mint(tickLower, tickUpper, WETHAmt, USDCAmt, WETHAmtMin, USDCAmtMin);
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

    function _addLiquidity(uint WETHAmt, uint USDCAmt, uint WETHAmtMin, uint USDCAmtMin) private {
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: WETHAmt,
                    amount1Desired: USDCAmt,
                    amount0Min: WETHAmtMin,
                    amount1Min: USDCAmtMin,
                    deadline: block.timestamp
                });
            nonfungiblePositionManager.increaseLiquidity(params);
            // console.log(WETH.balanceOf(address(this))); // 96931133882421968
            // console.log(USDC.balanceOf(address(this))); // 0
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
        uint WETHAmt,
        uint USDCAmt,
        uint WETHAmtMin,
        uint USDCAmtMin
    ) private {
        INonfungiblePositionManager.MintParams memory params =
                INonfungiblePositionManager.MintParams({
                    token0: address(WETH),
                    token1: address(USDC),
                    fee: poolFee,
                    // tickLower: -210000,
                    // tickUpper: -200000,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: WETHAmt,
                    amount1Desired: USDCAmt,
                    amount0Min: WETHAmtMin,
                    amount1Min: USDCAmtMin,
                    // amount0Min: 0,
                    // amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                });
            (uint _tokenId,,,) = nonfungiblePositionManager.mint(params);
            tokenId = _tokenId;
            // nonfungiblePositionManager.mint(params);
            // console.log(tokenId); // 57746
            // console.log(liquidity); // 0.000042216858555656
            // console.log(amount0); // 0.999999999999983820
            // console.log(amount1); // 1782.262559
            // console.log(WETH.balanceOf(address(this))); // 96931133882421968
            // console.log(USDC.balanceOf(address(this))); // 0
    }

    function getTicks(uint160 sqrtPriceX96Lower, uint160 sqrtPriceX96Upper) external pure returns (int24[] memory ticks) {
        ticks = new int24[](2);
        ticks[0] = TickMath.getTickAtSqrtRatio(sqrtPriceX96Lower);
        ticks[1] = TickMath.getTickAtSqrtRatio(sqrtPriceX96Upper);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

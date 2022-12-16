// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IWETH.sol";
import "../interface/IStargateRouter.sol";
import "../interface/ILayerZeroEndpoint.sol";

/// @title deposit/withdraw token between ethereum and optimism pool together
/// @author siew
contract PengHelperEth is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IWETH;

    IERC20Upgradeable constant WETH = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH constant SG_ETH = IWETH(0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c);
    IStargateRouter constant STARGATE_ROUTER = IStargateRouter(0x8731d54E9D02c286767d56ac03e8037C07e01e98);
    ILayerZeroEndpoint constant LZ_ENDPOINT = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
    address public pengHelperOp; // optimism

    event Deposit(address token, uint amount);
    event Withdraw(address token, uint amount);
    event SetPengHelperOp(address pengHelperOp_);

    function initialize(address pengHelperOp_) external initializer {
        require(pengHelperOp_ != address(0), "0 address");
        __Ownable_init();

        pengHelperOp = pengHelperOp_;

        SG_ETH.safeApprove(address(STARGATE_ROUTER), type(uint).max);
        USDC.safeApprove(address(STARGATE_ROUTER), type(uint).max);
    }

    /// @param amountOutMin amount minimum lp token to receive after deposit on peng together optimism
    /// @param gasLimit gas limit for calling sgReceive() on optimism
    /// @dev msg.value = eth deposit + bridge gas fee if deposit eth
    /// @dev msg.value = bridge gas fee if deposit usdc
    /// @dev bridge gas fee can retrieve from stargateRouter.quoteLayerZeroFee()
    function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin, uint gasLimit) external payable {
        require(token == WETH || token == USDC, "weth or usdc only");
        address msgSender = msg.sender;
        uint msgValue = msg.value;
        uint poolId;
        
        if (token == WETH) {
            require(amount >= 0.1 ether, "min 0.1 ether");
            require(msgValue > amount, "msg.value < amount");
            // deposit native eth into sgEth
            SG_ETH.deposit{value: amount}();
            // remaining msg.value for gas fee for stargate router swap
            msgValue -= amount;
            // poolId 13 = eth in stargate for both ethereum & optimism
            poolId = 13;

        } else { // token == usdc
            require(amount >= 100e6, "min $100");
            
            USDC.safeTransferFrom(msgSender, address(this), amount);
            // poolId 1 = usdc in stargate for both ethereum & optimism
            poolId = 1;
        }

        // deliberately assign minAmount, lzTxParams and payload to solve stack too deep error
        uint minAmount = amount * 995 / 1000;
        IStargateRouter.LzTxObj memory lzTxParams = IStargateRouter.LzTxObj(gasLimit, 0, "0x");
        bytes memory payload = abi.encode(msgSender, address(token), amountOutMin);
        STARGATE_ROUTER.swap{value: msgValue}(
            111, // _dstChainId, optimism
            poolId, // _srcPoolId
            poolId, // _dstPoolId
            payable(msgSender), // _refundAddress
            amount, // _amountLD
            minAmount, // _minAmountLD, 0.5% slippage
            lzTxParams, // _lzTxParams
            abi.encodePacked(pengHelperOp), // _to
            payload // _payload
        );

        emit Deposit(address(token), amount);
    }

    /// @param amountOutMin amount minimum token to receive after withdraw from peng together on optimism side
    /// @param gasLimit gas limit for calling lzReceive() on optimism
    /// @param nativeForDst gas fee used by stargate router optimism to bridge token to msg.sender in ethereum
    /// @dev msg.value = bridged gas fee + nativeForDst, can retrieve from lzEndpoint.estimateFees()
    /// @dev nativeForDst can retrieve from stargateRouter.quoteLayerZeroFee()
    function withdraw(
        IERC20Upgradeable token,
        uint amount,
        uint amountOutMin,
        uint gasLimit, 
        uint nativeForDst
    ) external payable {
        require(token == WETH || token == USDC, "weth or usdc only");
        require(amount > 0, "invalid amount");
        address msgSender = msg.sender;
        address pengHelperOp_ = pengHelperOp;

        LZ_ENDPOINT.send{value: msg.value}(
            111, // _dstChainId, optimism
            abi.encodePacked(pengHelperOp_, address(this)), // _destination
            abi.encode(address(token), amount, amountOutMin, msgSender), // _payload
            payable(msgSender), // _refundAddress
            address(0), // _zroPaymentAddress
            abi.encodePacked( // _adapterParams
                uint16(2), // version 2, set gas limit + airdrop nativeForDst
                gasLimit, // gasAmount
                nativeForDst, // nativeForDst, refer @param above
                pengHelperOp_ // addressOnDst
            )
        );

        emit Withdraw(address(token), amount);
    }

    /// @notice to receive eth send from user
    receive() external payable {}

    /// @notice pause deposit, only callable by owner
    function pauseContract() external onlyOwner {
        _pause();
    }

    /// @notice unpause deposit, only callable by owner
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    /// @notice set new peng helper optimism contract, only callable by owner
    /// @param pengHelperOp_ new peng helper optimism contract address
    function setPengHelperOp(address pengHelperOp_) external onlyOwner {
        require(pengHelperOp_ != address(0), "0 address");
        pengHelperOp = pengHelperOp_;

        emit SetPengHelperOp(pengHelperOp_);
    }

    /// @dev for uups upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
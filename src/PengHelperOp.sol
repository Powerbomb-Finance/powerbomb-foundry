// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IStargateRouter.sol";
import "../interface/IStargateRouterETH.sol";
import "../interface/ILayerZeroEndpoint.sol";
import "../interface/IVault.sol";

contract PengHelperOp is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable constant WETH_ETH = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable constant USDC_ETH = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IStargateRouter constant STARGATE_ROUTER = IStargateRouter(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);
    IStargateRouterETH constant STARGATE_ROUTER_ETH = IStargateRouterETH(0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b);
    IVault constant VAULT_SUSD = IVault(0x68ca3a3BBD306293e693871E45Fe908C04387614);
    IVault constant VAULT_SETH = IVault(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250);
    ILayerZeroEndpoint constant LZ_ENDPOINT = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);
    address constant PS_TOKEN_TRANSFER_PROXY = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;
    address constant PS_AUGUSTUS_SWAPPER = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
    mapping(uint16 => bytes) public trustedRemoteLookup; // PengHelper contract on Ethereum
    address public pengHelperEth;

    event SgReceive(uint16 chainId, address token, uint amount, bytes payload);
    event LzReceive(uint16 _srcChainId, bytes srcAddress, bytes payload);
    event LzReceiveRetry(bytes payload);
    event LzReceiveClear();
    event DepositOnBehalf(address token, uint amount, address account);
    event Bridged(address token, uint amount, address receiver);
    event SwitchVault();
    event WithdrawStuck(uint usdcAmt, uint ethAmt);
    event SetPengHelperEth(address pengHelperEth_);

    function initialize() external initializer {
        __Ownable_init();

        USDC.safeApprove(address(VAULT_SUSD), type(uint).max);
        USDC.safeApprove(address(STARGATE_ROUTER), type(uint).max);
    }

    /// @dev this function is for bridge funds from ethereum and deposit into peng together
    function sgReceive(
        uint16 chainId,
        bytes memory, // srcAddress
        uint, // _nonce
        address token_, // _token
        uint amount, // amountLD
        bytes memory payload
    ) external {
        require(msg.sender == address(STARGATE_ROUTER), "only stargate router");
        // srcAddress is not pengHelperEth contract address passed by stargate router
        // there is no way to check if srcAddress is pengHelperEth
        // but is okay, because amount deposit into peng together is the amount bridged from ethereum (minus protocol fee)
        // so there is no risk if srcAddress is not pengHelperEth
        // in fact, anyone from any chain can call this function as long as token bridge successfully into this contract
        // and deposit into peng together

        (address account, address token, uint amountOutMin) = abi.decode(payload, (address, address, uint));
        // USDC_ETH & WETH_ETH: USDC & WETH address in payload from ethereum is token address in ethereum
        if (token == address(USDC_ETH)) {
            VAULT_SUSD.depositByHelper(address(USDC), amount, amountOutMin, account);

        } else if (token == address(WETH_ETH)) {
            VAULT_SETH.depositByHelper{value: amount}(address(WETH), amount, amountOutMin, account);
        }

        emit SgReceive(chainId, token_, amount, payload);
    }

    /// @dev this function is for send message from ethereum, withdraw from peng together
    /// @dev and bridge funds to depositor in ethereum
    function lzReceive(uint16 srcChainId, bytes calldata srcAddress, uint64, bytes memory payload) external {
        require(msg.sender == address(LZ_ENDPOINT), "sender != LZ_ENDPOINT");
        require(keccak256(srcAddress) == keccak256(trustedRemoteLookup[srcChainId]), "srcAddr != trustedRemote");
        
        (
            address token, uint amount, uint amountOutMin, address account
        ) = abi.decode(payload, (address, uint, uint, address));

        // address(this).balance is gas fee for bridge token to ethereum, which airdrop from ethereum peng helper
        // remaining funds will return to this contract
        uint gas = address(this).balance;
        // USDC_ETH & WETH_ETH: USDC & WETH address in payload from ethereum is token address in ethereum
        if (token == address(USDC_ETH)) {
            // withdraw from peng together to this contract
            uint withdrawAmt = VAULT_SUSD.withdrawByHelper(address(USDC), amount, amountOutMin, account);
            // bridge USDC from this contract to msg.sender in ethereum
            STARGATE_ROUTER.swap{value: gas}(
                101, // _dstChainId
                1, // _srcPoolId
                1, // _dstPoolId
                payable(address(this)), // _refundAddress
                withdrawAmt, // _amountLD
                withdrawAmt * 995 / 1000, // _minAmountLD, 0.5%
                IStargateRouter.LzTxObj(0, 0, "0x"), // _lzTxParams
                abi.encodePacked(account), // _to
                bytes("") // _payload
            );
            emit Bridged(address(USDC), withdrawAmt, account);

        } else if (token == address(WETH_ETH)) {
            // withdraw from peng together to this contract
            uint withdrawAmt = VAULT_SETH.withdrawByHelper(address(WETH), amount, amountOutMin, account);
            // bridge eth from this contract to msg.sender in ethereum
            STARGATE_ROUTER_ETH.swapETH{value: withdrawAmt + gas}(
                101, // _dstChainId
                address(this), // _refundAddress
                abi.encodePacked(account), // _toAddress
                withdrawAmt, // _amountLD
                withdrawAmt * 995 / 1000 // _minAmountLD, 0.5%
            );
            emit Bridged(address(WETH), withdrawAmt, account);
        }

        emit LzReceive(srcChainId, srcAddress, payload);
    }

    receive() external payable {}

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    /// @notice retrieve any payload that didn't execute due to error, can view from layerzeroscan.com
    /// @notice can call by anyone
    /// @param payload abi.encode(address(token), amount, amountOutMin, msgSender)
    function lzReceiveRetry(bytes calldata payload) external {
        bytes memory srcAddress = abi.encodePacked(pengHelperEth, address(this));
        LZ_ENDPOINT.retryPayload(101, srcAddress, payload);

        emit LzReceiveRetry(payload);
    }

    /// @notice clear any payload that block the subsequent payload
    function lzReceiveClear() external onlyOwner {
        bytes memory srcAddress = abi.encodePacked(pengHelperEth, address(this));
        LZ_ENDPOINT.forceResumeReceive(101, srcAddress);

        emit LzReceiveClear();
    }

    /// @notice deposit on behalf of an account
    function depositOnBehalf(address token, uint amount, uint amountOutMin, address account) external payable {
        if (token == address(USDC)) {
            USDC.safeTransferFrom(msg.sender, address(this), amount);
            VAULT_SUSD.depositByHelper(address(USDC), amount, amountOutMin, account);

        } else if (token == address(WETH)) {
            VAULT_SETH.depositByHelper{value: amount}(address(WETH), amount, amountOutMin, account);
        }

        emit DepositOnBehalf(token, amount, account);
    }

    /// @notice switch user funds within vaults, tokens swap by paraswap
    function switchVault(
        address fromVaultAddr,
        address toVaultAddr,
        uint amountWithdraw, // amount to withdraw from vault
        uint amountToSwap, // amount to swap with paraswap, this amount will slightly lesser than amount to withdraw
        // to prevent swap error due to slippage, in normal case same with amountOutMinWithdraw
        uint[] memory amountsOutMin, // [amountOutMinWithdraw, amountOutMinDeposit]
        bytes memory data // paraswap data
    ) external {
        address msgSender = msg.sender;
        uint usdcBal = USDC.balanceOf(address(this));
        uint ethBal = address(this).balance;
        uint actualWithdrawAmt;

        if (fromVaultAddr == address(VAULT_SUSD) && toVaultAddr == address(VAULT_SETH)) {
            // withdraw from VAULT_SUSD
            actualWithdrawAmt = VAULT_SUSD.withdrawByHelper(address(USDC), amountWithdraw, amountsOutMin[0], msgSender);
            // swap USDC to eth
            (bool success,) = PS_AUGUSTUS_SWAPPER.call(data);
            require(success, "Paraswap swap error");

            uint ethReceived = address(this).balance - ethBal;
            // deposit eth into VAULT_SETH
            VAULT_SETH.depositByHelper{value: ethReceived}(address(WETH), ethReceived, amountsOutMin[1], msgSender);

            uint usdcLeft = USDC.balanceOf(address(this)) - usdcBal;
            // since amountToSwap == amountOutMinWithdraw, if swap success,
            // actualWithdrawAmt > amountToSwap(amountOutMinWithdraw), return leftover to user
            if (usdcLeft > 0) USDC.safeTransfer(msgSender, usdcLeft);

        } else if (fromVaultAddr == address(VAULT_SETH) && toVaultAddr == address(VAULT_SUSD)) {
            // withdraw from VAULT_SETH
            actualWithdrawAmt = VAULT_SETH.withdrawByHelper(address(WETH), amountWithdraw, amountsOutMin[0], msgSender);
            // swap eth to USDC
            bool success = false;
            (success,) = PS_AUGUSTUS_SWAPPER.call{value: amountToSwap}(data);
            require(success, "Paraswap swap error");

            uint usdcReceived = USDC.balanceOf(address(this)) - usdcBal;
            // deposit USDC into VAULT_SUSD
            VAULT_SUSD.depositByHelper(address(USDC), usdcReceived, amountsOutMin[1], msgSender);

            uint ethLeft = address(this).balance - ethBal;
            if (ethLeft > 0) {
                // since amountToSwap == amountOutMinWithdraw, if swap success,
                // actualWithdrawAmt > amountToSwap(amountOutMinWithdraw), return leftover to user
                bool success_ = false;
                (success_,) = msgSender.call{value: ethLeft}("");
                // slither show this as dangerous calls but, msgSender withdraw nothing if ethLeft = 0,
                // which record eth balance from the beginning of this function, and calculate ethLeft by
                // check address(this).balance minus eth balance recorded
                require(success_, "eth transfer failed");
            }
        }

        emit SwitchVault();
    }

    /// @notice withdraw any USDC or eth stuck in this contract due to fail deposit into peng together
    function withdrawStuck() external onlyOwner {
        address owner_ = owner();

        // USDC
        uint usdcAmt = USDC.balanceOf(address(this));
        if (usdcAmt > 0) {
            USDC.safeTransfer(owner_, usdcAmt);
        }

        // eth
        uint ethAmt = address(this).balance;
        if (ethAmt > 0) {
            (bool success,) = owner_.call{value: ethAmt}("");
            require(success);
        }

        emit WithdrawStuck(usdcAmt, ethAmt);
    }

    /// @notice approve erc20 token to paraswap TokenTransferProxy contract to perform swap
    /// @dev note that swap is done by AugustusSwapper contract but
    ///erc20 tokens have to approve TokenTransferProxy contract instead
    function approveParaswapTokenTransferProxy(address token) external onlyOwner {
        IERC20Upgradeable(token).safeApprove(PS_TOKEN_TRANSFER_PROXY, type(uint).max);
    }

    function setPengHelperEth(address pengHelperEth_) external onlyOwner {
        require(pengHelperEth_ != address(0), "address(0)");
        pengHelperEth = pengHelperEth_;
        trustedRemoteLookup[101] = abi.encodePacked(pengHelperEth_, address(this));

        emit SetPengHelperEth(pengHelperEth_);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
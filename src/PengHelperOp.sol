// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IStargateRouter.sol";
import "../interface/IStargateRouterETH.sol";
import "../interface/IVault.sol";

contract PengHelperOp is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {

    IERC20Upgradeable constant weth = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable constant usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IStargateRouter constant stargateRouter = IStargateRouter(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);
    IStargateRouterETH constant stargateRouterEth = IStargateRouterETH(0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b);
    IVault constant vaultSusd = IVault(0x68ca3a3BBD306293e693871E45Fe908C04387614);
    IVault constant vaultSeth = IVault(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250);
    address constant lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    mapping(uint16 => bytes) public trustedRemoteLookup; // PengHelper contract on Ethereum
    address public pengHelperEth;

    // IERC20Upgradeable constant weth = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    // IERC20Upgradeable constant usdc = IERC20Upgradeable(0x0CEDBAF2D0bFF895C861c5422544090EEdC653Bf);
    // IStargateRouter constant stargateRouter = IStargateRouter(0x95461eF0e0ecabC049a5c4a6B98Ca7B335FAF068);

    // TODO events
    // event SetTrustedRemote(uint16 chainId, address record);
    // event SgReceive(address token, uint tokenBalance, uint amount, address depositor, uint amountOutMin, uint16 chainId, bytes srcAddress, bytes payload);

    function initialize() external initializer {
        __Ownable_init();

        usdc.approve(address(vaultSusd), type(uint).max);
        usdc.approve(address(stargateRouter), type(uint).max);
    }

    ///@dev this function is for bridge funds from ethereum and deposit into peng together
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint, // _nonce
        address, // _token
        uint amount, // amountLD
        bytes memory _payload
    ) external {
        require(msg.sender == address(stargateRouter), "only stargate router");
        address srcAddress = abi.decode(_srcAddress, (address));
        require(_chainId == 101 && srcAddress == pengHelperEth, "invalid chainId or srcAddress");

        (address account, address token_, uint amountOutMin) = abi.decode(_payload, (address, address, uint));
        if (token_ == address(usdc)) {
            vaultSusd.depositByHelper(token_, amount, amountOutMin, account);
        } else if (token_ == address(weth)) {
            vaultSeth.depositByHelper{value: amount}(token_, amount, amountOutMin, account);
        }

        // uint tokenBalance = token == address(weth) ? address(this).balance : usdc.balanceOf(address(this));
        // emit SgReceive(token, tokenBalance, amount, depositor, amountOutMin, _chainId, srcAddress, payload);
    }

    ///@dev this function is for send message from ethereum, withdraw from peng together
    ///@dev and bridge funds to depositor in ethereum
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64, bytes memory _payload) external {
        require(msg.sender == address(lzEndpoint), "sender != lzEndpoint");
        require(keccak256(_srcAddress) == keccak256(trustedRemoteLookup[_srcChainId]), "srcAddr != trustedRemote");
        
        (
            address token, uint amount, uint amountOutMin, address account
        ) = abi.decode(_payload, (address, uint, uint, address));

        // address(this).balance is gas fee for bridge token to ethereum, which airdrop from ethereum peng helper
        // remaining funds will return to this contract
        uint gas = address(this).balance;
        if (token == address(usdc)) {
            uint withdrawAmt = vaultSusd.withdrawByHelper(token, amount, amountOutMin, account);
            stargateRouter.swap{value: gas}(
                101, // _dstChainId
                1, // _srcPoolId
                1, // _dstPoolId
                payable(address(this)), // _refundAddress
                withdrawAmt, // _amountLD
                withdrawAmt * 995 / 1000, // _minAmountLD, 0.5%
                IStargateRouter.lzTxObj(0, 0, "0x"), // _lzTxParams
                abi.encodePacked(account), // _to
                bytes("") // _payload
            );
        } else if (token == address(weth)) {
            uint withdrawAmt = vaultSeth.withdrawByHelper(token, amount, amountOutMin, account);
            stargateRouterEth.swapETH{value: withdrawAmt + gas}(
                101, // _dstChainId
                address(this), // _refundAddress
                abi.encodePacked(account), // _toAddress
                withdrawAmt, // _amountLD
                withdrawAmt * 995 / 1000 // _minAmountLD, 0.5%
            );
        }
    }

    receive() external payable {}

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function setPengHelperEth(address _pengHelperEth) external {
        pengHelperEth = _pengHelperEth;
        trustedRemoteLookup[101] = abi.encodePacked(_pengHelperEth, address(this));

        // TODO emit event
    }

    // function setTrustedRemote(uint16 chainId, address record) external onlyOwner {
    //     trustedRemoteLookup[chainId] = abi.encodePacked(record, address(this));

    //     emit SetTrustedRemote(chainId, record);
    // }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
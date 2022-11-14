// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IWETH.sol";
import "../interface/IStargateRouter.sol";

contract PengTogether is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {

    IWETH constant weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable constant usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IStargateRouter constant router = IStargateRouter(0x8731d54E9D02c286767d56ac03e8037C07e01e98);
    IStargateRouter constant routerEth = IStargateRouter(0x150f94B44927F078737562f0fcF3C95c01Cc2376);
    address public pengTogetherHelper;

    // TODO events

    function initialize(address _pengTogetherHelper) external {
        __Ownable_init();

        pengTogetherHelper = _pengTogetherHelper;
    }

    // function deposit(IERC20Upgradeable token, uint amount, uint amountOutMin) external payable {
    //     require(token == weth || token == usdc, "weth or usdc only");
        
    //     if (token == weth) {
    //         require(amount >= 0.1 ether, "min 0.1 ether");
    //         uint msgValue = msg.value;
    //         require(msgValue > amount, "msg.value < amount");

    //         weth.deposit{value: amount}();

    //         uint gas = msgValue - amount;
    //         router.swap{value: gas}(
    //             111,
    //             13,
    //             13,
    //             payable(msg.sender),
    //             amount,
    //             amount * 995 / 1000, // 0.5% slippage
    //             IStargateRouter.lzTxObj(0, 0, "0x"), // TODO additional gasLimit increase
    //             abi.encodePacked(pengTogetherHelper),
    //             bytes("") // TODO payload
    //         );

    //     } else { // token == usdc
    //         require(amount >= 100e6, "min $100");
    //         //
    //     }
    // }

    // receive() external payable {}

    // function withdraw(IERC20Upgradeable token, uint amount, uint amountOutMin) external {
    //     require(token == weth || token == usdc, "weth or usdc only");
    //     require(amount > 0, "invalid amount");
    //     //
    // }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    function setPengTogetherHelper(address _pengTogetherHelper) external {
        pengTogetherHelper = _pengTogetherHelper;

        // TODO emit event
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
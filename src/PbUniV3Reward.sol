// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ISwapRouter.sol";

import "forge-std/Test.sol";

contract PbUniV3Reward is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address public pbUniV3;

    modifier onlyAuthorized {
        require(msg.sender == pbUniV3 || msg.sender == owner(), "Only authorized");
        _;
    }

    function initialize(address _pbUniV3) external initializer {
        pbUniV3 = _pbUniV3;
    }

    function deposit(IERC20Upgradeable rewardToken, uint amount) external nonReentrant whenNotPaused {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external {
        
    }

    function harvest() external {
        
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

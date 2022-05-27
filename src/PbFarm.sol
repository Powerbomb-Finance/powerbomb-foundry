// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "oz-upgradeable/security/PausableUpgradeable.sol";
import "oz-upgradeable/proxy/utils/Initializable.sol";
import "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./lib/NonblockingLzApp.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IStake.sol";

contract PbFarm is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, NonblockingLzApp {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public USDT;
    IERC20Upgradeable public USDC;
    bool public isFarm;
    IPool public pool;
    IStake public stake;

    function initialize(IERC20Upgradeable _USDT, IERC20Upgradeable _USDC, bool _isFarm, IPool _pool, IStake _stake) external initializer {
        __Ownable_init();

        USDT = _USDT;
        USDC = _USDC;
        isFarm = _isFarm;
        pool = _pool;
        stake = _stake;
    } 

    function deposit(IERC20Upgradeable token, uint amount) public {
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    /// @notice for bot calling deposit function when there's funds in
    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory) internal override {
        // Optimism doesn't have USDT
        uint USDTBal = block.chainid == 10 ? 0 : USDT.balanceOf(address(this));
        if (USDTBal > 0) {
            deposit(USDT, USDTBal);
        }

        uint USDCBal = USDC.balanceOf(address(this));
        if (USDCBal > 0) {
            deposit(USDC, USDCBal);
        }
    }

    function setIsFarm() external onlyOwner {
        isFarm = !isFarm;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

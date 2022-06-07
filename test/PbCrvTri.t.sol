// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/PbCrvTri.sol";
import "../src/PbCrvTriReward.sol";
import "../src/PbCrvTriRewardBTC.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PbCrvTriTest is Test {
    IERC20Upgradeable constant USDT = IERC20Upgradeable(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20Upgradeable constant WBTC = IERC20Upgradeable(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20Upgradeable constant WETH = IERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20Upgradeable constant CRV = IERC20Upgradeable(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20Upgradeable constant crv3crypto = IERC20Upgradeable(0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2);
    IPool constant pool = IPool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    IGauge constant gauge = IGauge(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    IRouter constant router = IRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // Sushi

    PbCrvTri vault;
    PbCrvTriReward rewardWETH;
    PbCrvTriReward rewardWBTC;

    function setUp() public {
        vault = new PbCrvTri();
        vault.initialize();

        rewardWETH = new PbCrvTriReward();
        rewardWETH.initialize(address(vault), address(this));

        rewardWBTC = new PbCrvTriRewardBTC();
        rewardWBTC.initialize(address(vault), address(this));
        
        vault.setNewReward(address(rewardWETH), address(WETH));
        vault.setNewReward(address(rewardWBTC), address(WBTC));
    }

    function test() public {
        deal(address(WETH), address(this), 15 ether);
        WETH.approve(address(vault), type(uint).max);
        vault.deposit(WETH, 10 ether, 0, address(WETH));
        vault.deposit(WETH, 5 ether, 0, address(WBTC));
        deal(address(CRV), address(gauge), CRV.balanceOf(address(gauge)) + 10000 ether);
        vault.harvest();
        console.log(vault.getUserPendingReward(address(this), address(WETH))); // 8.9837
        console.log(vault.getUserPendingReward(address(this), address(WBTC))); // 4.54216
    }
}

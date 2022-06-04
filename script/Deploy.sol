// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "src/PbVelo.sol";
import "src/PbVeloProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address WETH = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    function run() public {
        vm.startBroadcast();

        PbVelo vault = new PbVelo();
        PbVeloProxy proxy = new PbVeloProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address,address,address,address,address,address)")),
                0x888EF71766ca594DED1F0FA3AE64eD2941740A20, // _VELO
                0x1d1A1871d1830D4b5087212c820E5f1252379c2c, // _gauge
                WETH, // _rewardToken
                // WBTC, // _rewardToken
                0x794a61358D6845594F94dc1DB02A252b5b4814aD, // _lendingPool
                0xa38cd27185a464914D3046f0AB9d43356B34829D, // _router
                WETH, // _WETH
                0xf4766552D15AE4d256Ad41B6cf2933482B0680dc, // _WETHPriceFeed
                address(1) // _treasury
            )
        );
        console.log("Proxy contract", address(proxy));
        console.log("Implementation contract", address(vault));
    }
}
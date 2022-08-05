// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "src/PbVelo.sol";
import "src/PbProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address treasury = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address WETH = 0x4200000000000000000000000000000000000006;

    function run() public {
        vm.startBroadcast();

        // PbVelo vaultImpl = new PbVelo();
        address vaultImpl = 0x0f5272057faC3b5B640130C390876187Fa603075;

        PbProxy proxyBTC = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address)")),
                0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80, // _gauge
                WBTC, // _rewardToken
                treasury // _treasury
            )
        );
        console.log("Proxy contract for BTC reward", address(proxyBTC));

        PbProxy proxyETH = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address)")),
                0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80, // _gauge
                WETH, // _rewardToken
                treasury // _treasury
            )
        );
        console.log("Proxy contract for ETH reward", address(proxyETH));
    }
}

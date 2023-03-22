// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/PbVelo.sol";
import "src/PbProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address treasury = 0x96E2951CAbeF46E547Ae9eEDc3245d69deA0Be49;
    address WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address WETH = 0x4200000000000000000000000000000000000006;
    address USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address gauge = 0x101D5e5651D7f949154258C1C7516da1eC273476;

    function run() public {
        vm.startBroadcast();

        PbVelo vaultImpl = new PbVelo();
        // address vaultImpl = 0x14dCFEff5ce62777F34A801270DdaFb044645c37;

        PbProxy proxyBTC = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                gaugeAddr, // gauge_
                WBTC, // rewardToken_
                treasury, // treasury_
                0.001 ether // swapThreshold_
            )
        );
        console.log("Proxy contract for BTC reward", address(proxyBTC));

        PbProxy proxyETH = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                PbVelo.initialize.selector,
                gaugeAddr, // gauge_
                WETH, // rewardToken_
                treasury, // treasury_
                0.001 ether // swapThreshold_
            )
        );
        console.log("Proxy contract for ETH reward", address(proxyETH));

        // PbProxy proxyUSDC = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         PbVelo.initialize.selector,
        //         gaugaAddr, // gauge_
        //         USDC, // rewardToken_
        //         treasury // treasury_
                // 0.001 ether // swapThreshold_
        //     )
        // );
        // console.log("Proxy contract for USDC reward", address(proxyUSDC));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "src/PbVelo.sol";
import "src/PbProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address treasury = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address WETH = 0x4200000000000000000000000000000000000006;
    address USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    function run() public {
        vm.startBroadcast();

        // PbVelo vaultImpl = new PbVelo();
        address vaultImpl = 0x14dCFEff5ce62777F34A801270DdaFb044645c37;

        // PbProxy proxyBTC = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0xE2CEc8aB811B648bA7B1691Ce08d5E800Dd0a60a, // _gauge
        //         WBTC, // _rewardToken
        //         treasury // _treasury
        //     )
        // );
        // console.log("Proxy contract for BTC reward", address(proxyBTC));

        // PbProxy proxyETH = new PbProxy(
        //     address(vaultImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address,address)")),
        //         0xE2CEc8aB811B648bA7B1691Ce08d5E800Dd0a60a, // _gauge
        //         WETH, // _rewardToken
        //         treasury // _treasury
        //     )
        // );
        // console.log("Proxy contract for ETH reward", address(proxyETH));

        PbProxy proxyUSDC = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address,address)")),
                0x101D5e5651D7f949154258C1C7516da1eC273476, // _gauge
                USDC, // _rewardToken
                treasury // _treasury
            )
        );
        console.log("Proxy contract for USDC reward", address(proxyUSDC));
    }
}

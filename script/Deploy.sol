// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/PbProxy.sol";
import "src/PbCvxSteth.sol";

contract Deploy is Script {

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() public {
        vm.startBroadcast();

        PbCvxSteth vaultImpl = new PbCvxSteth();
        new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address,address)")),
                25,
                0xDC24316b9AE028F1497c275EB9192a3Ea0f67022,
                usdc
            )
        );
    }
}
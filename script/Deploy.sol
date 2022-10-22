// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/PbProxy.sol";
import "src/PbAuraWsteth.sol";

contract Deploy is Script {

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() public {
        vm.startBroadcast();

        PbAuraWsteth vaultImpl = new PbAuraWsteth();
        new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address)")),
                3,
                usdc
            )
        );
    }
}
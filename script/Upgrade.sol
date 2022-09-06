// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "src/PbVelo.sol";
import "forge-std/Script.sol";

contract Upgrade is Script {

    function run() public {
        vm.startBroadcast();

        PbVelo vaultImpl = new PbVelo();

        PbVelo vault1 = PbVelo(payable(0x208e2D48b5A080E57792D8b175De914Ddb18F9a8));
        vault1.upgradeTo(address(vaultImpl));

        PbVelo vault2 = PbVelo(payable(0x208e2D48b5A080E57792D8b175De914Ddb18F9a8));
        vault2.upgradeTo(address(vaultImpl));
    }
}

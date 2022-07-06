// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/PbCrvArbTri.sol";

contract Upgrade is Script {
    PbCrvArbTri strat;
    
    function run() public {
        vm.startBroadcast();

        PbCrvArbTri stratImpl = new PbCrvArbTri();
        strat = PbCrvArbTri(payable(0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5));
        strat.upgradeTo(address(stratImpl));
        strat = PbCrvArbTri(payable(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631));
        strat.upgradeTo(address(stratImpl));
        strat = PbCrvArbTri(payable(0x8Ae32c034dAcd85a79CFd135050FCb8e6D4207D8));
        strat.upgradeTo(address(stratImpl));
    }
}

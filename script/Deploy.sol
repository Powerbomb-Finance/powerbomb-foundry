// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "../src/PengTogether.sol";
import "../src/FarmCurve.sol";
import "../src/PbProxy.sol";

contract Deploy is Script {

    function run() public {
        vm.startBroadcast();

        FarmCurve farm = new FarmCurve();
        PbProxy farmProxy = new PbProxy(
            address(farm),
            abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        );
        farm = FarmCurve(payable(address(farmProxy)));
        console.log("farm:", address(farm));

        PengTogether vault = new PengTogether();
        PbProxy vaultProxy = new PbProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address)")),
                address(farm)
            )
        );
        vault = PengTogether(address(vaultProxy));
        console.log("vault:", address(vault));

        farm.setVault(address(vault));
    }
}

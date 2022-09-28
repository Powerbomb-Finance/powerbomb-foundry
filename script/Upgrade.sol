// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
// import "src/PbCrvOpUsd.sol";
// import "src/PbCrvOpEth.sol";
import "src/PbCrvPolyTri.sol";

contract Upgrade is Script {
    PbCrvPolyTri vault;
    
    function run() public {
        vm.startBroadcast();

        PbCrvPolyTri vaultImpl = new PbCrvPolyTri();

        vault = PbCrvPolyTri(0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab);
        vault.upgradeTo(address(vaultImpl));

        vault = PbCrvPolyTri(0x5abbEB3323D4B19C4C371C9B056390239FC0Bf43);
        vault.upgradeTo(address(vaultImpl));

        vault = PbCrvPolyTri(0x7331f946809406F455623d0e69612151655e8261);
        vault.upgradeTo(address(vaultImpl));
    }
}
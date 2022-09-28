// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/PbCrvOpUsd.sol";
import "src/PbCrvOpEth.sol";
// import "src/PbCrvPolyTri.sol";

contract Upgrade is Script {
    PbCrvOpUsd vaultUsd;
    PbCrvOpEth vaultEth;
    
    function run() public {
        vm.startBroadcast();

        PbCrvOpUsd vaultUsdImpl = new PbCrvOpUsd();

        vaultUsd = PbCrvOpUsd(0x61F157E08b2B55eB3B0dD137c1D2A73C9AB5888e);
        vaultUsd.upgradeTo(address(vaultUsdImpl));

        vaultUsd = PbCrvOpUsd(0xA8e39872452BA48b1F4c7e16b78668199d2C41Dd);
        vaultUsd.upgradeTo(address(vaultUsdImpl));

        PbCrvOpEth vaultEthImpl = new PbCrvOpEth();

        vaultEth = PbCrvOpEth(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631);
        vaultEth.upgradeTo(address(vaultEthImpl));
    }
}
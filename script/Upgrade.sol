// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/PbCrvOpUsd.sol";
import "src/PbCrvOpEth.sol";

contract Upgrade is Script {
    PbCrvOpUsd stratUsdBtc;
    PbCrvOpUsd stratUsdEth;
    PbCrvOpEth stratEth;
    
    function run() public {
        vm.startBroadcast();

        PbCrvOpUsd stratUsdImpl = new PbCrvOpUsd();

        stratUsdBtc = PbCrvOpUsd(0x61F157E08b2B55eB3B0dD137c1D2A73C9AB5888e);
        stratUsdBtc.upgradeTo(address(stratUsdImpl));

        stratUsdEth = PbCrvOpUsd(0xA8e39872452BA48b1F4c7e16b78668199d2C41Dd);
        stratUsdEth.upgradeTo(address(stratUsdImpl));

        PbCrvOpEth stratEthImpl = new PbCrvOpEth();
        stratEth = PbCrvOpEth(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631);
        stratEth.upgradeTo(address(stratEthImpl));
    }
}

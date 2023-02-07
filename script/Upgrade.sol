// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
// import "src/PbCrvOpUsd.sol";
// import "src/PbCrvOpEth.sol";
// import "src/PbCrvPolyTri.sol";
import "src/PbCrvArb2p.sol";
import "src/PbCrvArbTri.sol";

contract Upgrade is Script {
    // PbCrvOpUsd vaultUsd;
    // PbCrvOpEth vaultEth;
    PbCrvArb2p vault2pBTC;
    PbCrvArb2p vault2pETH;
    PbCrvArbTri vaultTriBTC;
    PbCrvArbTri vaultTriETH;
    PbCrvArbTri vaultTriUSDT;
    
    function run() public {
        vm.startBroadcast();

        // PbCrvOpUsd vaultUsdImpl = new PbCrvOpUsd();

        // vaultUsd = PbCrvOpUsd(0x61F157E08b2B55eB3B0dD137c1D2A73C9AB5888e);
        // vaultUsd.upgradeTo(address(vaultUsdImpl));

        // vaultUsd = PbCrvOpUsd(0xA8e39872452BA48b1F4c7e16b78668199d2C41Dd);
        // vaultUsd.upgradeTo(address(vaultUsdImpl));

        // PbCrvOpEth vaultEthImpl = new PbCrvOpEth();

        // vaultEth = PbCrvOpEth(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631);
        // vaultEth.upgradeTo(address(vaultEthImpl));


        // // PbCrvArb2p vault2pImpl = new PbCrvArb2p();
        // PbCrvArb2p vault2pImpl = PbCrvArb2p(0x14dCFEff5ce62777F34A801270DdaFb044645c37);

        // vault2pBTC = PbCrvArb2p(0xE616e7e282709d8B05821a033B43a358a6ea8408);
        // vault2pBTC.upgradeTo(address(vault2pImpl));
        // vault2pBTC.switchGauge();

        // vault2pETH = PbCrvArb2p(0xBE6A4db3480EFccAb2281F30fe97b897BeEf408c);
        // vault2pETH.upgradeTo(address(vault2pImpl));
        // vault2pETH.switchGauge();

        // // PbCrvArbTri vaultTriImpl = new PbCrvArbTri();
        // PbCrvArbTri vaultTriImpl = PbCrvArbTri(0xc23CF2762094a4Dd8DC3D4AaAAfdB38704B0f484)

        // vaultTriBTC = PbCrvArbTri(payable(0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5));
        // vaultTriBTC.upgradeTo(address(vaultTriImpl));
        // vaultTriBTC.switchGauge();

        // vaultTriETH = PbCrvArbTri(payable(0xb88C7a8e678B243a6851b9Fa82a1aA0986574631));
        // vaultTriETH.upgradeTo(address(vaultTriImpl));
        // vaultTriETH.switchGauge();

        // vaultTriUSDT = PbCrvArbTri(payable(0x8Ae32c034dAcd85a79CFd135050FCb8e6D4207D8));
        // vaultTriUSDT.upgradeTo(address(vaultTriImpl));
        // vaultTriUSDT.switchGauge();
    }
}
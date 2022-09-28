// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/PbProxy.sol";
import "src/PbCrvOpUsd.sol";
import "src/PbCrvOpEth.sol";

contract Deploy is Script {

    address treasuryAddr = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E; // Change this

    address WBTCAddr = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address WETHAddr = 0x4200000000000000000000000000000000000006;
    address USDCAddr = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    
    function run() public {
        vm.startBroadcast();

        // Optimism SUSD/3CRV BTC/ETH
        PbCrvOpUsd pbCrvOpUsdImpl = new PbCrvOpUsd();
        // address pbCrvOpUsdImpl = ;

        PbProxy pbCrvOpUsdProxy_WBTC = new PbProxy(
            address(pbCrvOpUsdImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                WBTCAddr,
                treasuryAddr
            )
        );
        console.log("pbCrvOpUsdProxy_WBTC:", address(pbCrvOpUsdProxy_WBTC));

        PbProxy pbCrvOpUsdProxy_WETH = new PbProxy(
            address(pbCrvOpUsdImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                WETHAddr,
                treasuryAddr
            )
        );
        console.log("pbCrvOpUsdProxy_WETH:", address(pbCrvOpUsdProxy_WETH));


        // Optimism SETH/ETH USDC
        PbCrvOpEth pbCrvOpEthImpl = new PbCrvOpEth();
        // address pbCrvOpEthImpl = ;

        PbProxy pbCrvOpEthProxy_USDC = new PbProxy(
            address(pbCrvOpEthImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                USDCAddr,
                treasuryAddr
            )
        );
        console.log("pbCrvOpEthProxy_USDC:", address(pbCrvOpEthProxy_USDC));
    }
}

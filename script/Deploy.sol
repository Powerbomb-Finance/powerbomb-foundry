// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "../src/PbProxy.sol";
import "../src/PengHelperEth.sol";
import "../src/PengHelperOp.sol";

contract Deploy is Script {

    function run() public {
        vm.startBroadcast();

        PbProxy proxy;

        PengHelperOp pengHelperOp = new PengHelperOp();
        proxy = new PbProxy(
            address(pengHelperOp),
            abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        );
        // PengHelperOp pengHelperOp = PengHelperOp(payable(0xcfb54CE9bb41BA8256843cC0FB036fad608865bB));

        // PengHelperEth pengHelperEth = new PengHelperEth();
        // proxy = new PbProxy(
        //     address(pengHelperEth),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(pengHelperOp)
        //     )
        // );
        // address pengHelperEth = 0x8afa0A68a7FD536f44B474DeBC93825b9De2ED43;

        // pengHelperOp.setPengHelperEth(address(pengHelperEth));
    }
}
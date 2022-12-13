// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import "../src/PbProxy.sol";
import "../src/PengHelperEth.sol";
import "../src/PengHelperOp.sol";

contract Deploy is Script {

    function run() public {
        vm.startBroadcast();

        // PbProxy proxy;

        // PengHelperOp pengHelperOp = new PengHelperOp();
        // proxy = new PbProxy(
        //     address(pengHelperOp),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        PengHelperOp pengHelperOp = PengHelperOp(payable(0xCf91CDBB4691a4b912928A00f809f356c0ef30D6));

        // PengHelperEth pengHelperEth = new PengHelperEth();
        // address pengHelperEth = 0x3cA2BeE859c592A17F8b15E353B28f3c05Cb1E01;
        // proxy = new PbProxy(
        //     address(pengHelperEth),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(pengHelperOp)
        //     )
        // );
        address pengHelperEth = 0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab;

        pengHelperOp.setPengHelperEth(address(pengHelperEth));
    }
}
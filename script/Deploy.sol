// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "../src/PbProxy.sol";

import "../src/PengTogether.sol";
import "../src/Record.sol";

import "../src/Reward.sol";
import "../src/Dao.sol";

contract Deploy is Script {

    PengTogether vault = PengTogether(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614)); // Optimism
    Record record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d); // Optimism
    address dao = 0x28BCc4202cd179499bF618DBfd1bFE37278E1A12;
    address reward = 0xF7A1f8918301D9C09105812eB045AA168aB3BFea;

    function run() public {
        vm.startBroadcast();

        // PbProxy proxy;

        // Record record = new Record();
        // proxy = new PbProxy(
        //     address(record),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // record = Record(address(proxy));

        // PengTogether vault = new PengTogether();
        // proxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(record)
        //     )
        // );
        // vault = PengTogether(payable(address(proxy)));

        // record.setVault(address(vault));

        // Dao dao = new Dao();
        // proxy = new PbProxy(
        //     address(dao),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,uint64,address)")),
        //         address(record), // record on Optimism
        //         414, // subscriptionId,
        //         0x524cAB2ec69124574082676e6F654a18df49A048 // lil pudgy
        //     )
        // );
        // dao = Dao(address(proxy));

        // Reward reward = new Reward();
        // proxy = new PbProxy(
        //     address(reward),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(dao),
        //         address(vault) // pengTogetherVault on Optimism
        //     )
        // );
        // reward = Reward(payable(address(proxy)));

        // dao.setReward(address(reward));

        record.setDao(dao);
        vault.setReward(reward);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "../src/PbProxy.sol";

import "../src/Vault_seth.sol";
import "../src/Record_eth.sol";

import "../src/Reward.sol";
import "../src/Dao.sol";

contract Deploy is Script {

    Vault_seth vault = Vault_seth(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250)); // Optimism
    Record record = Record(0xC530677144A7EA5BaE6Fbab0770358522b4e7071); // Optimism
    address dao = 0x0C9133Fa96d72C2030D63B6B35c3738D6329A313;
    address reward = 0xB7957FE76c2fEAe66B57CF3191aFD26d99EC5599;

    function run() public {
        vm.startBroadcast();

        // PbProxy proxy;

        // Record_eth record = new Record_eth();
        // proxy = new PbProxy(
        //     address(record),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // record = Record_eth(address(proxy));

        // Vault_seth vault = new Vault_seth();
        // proxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(record)
        //     )
        // );
        // vault = Vault_seth(payable(address(proxy)));

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
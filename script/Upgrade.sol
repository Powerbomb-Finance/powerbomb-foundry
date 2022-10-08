// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
// import "../src/PengTogether.sol";
import "../src/Vault_seth.sol";
// import "../src/Record.sol";
// import "../src/Reward.sol";

contract Upgrade is Script {
    // PengTogether vault = PengTogether(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    Vault_seth vault = Vault_seth(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    // Record record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d);
    // FarmCurve farm = FarmCurve(payable(0xA6cFCa9EB181728082D35419B58Ba7eE4c9c8d38));
    // Reward reward = Reward(payable(0xc052Ac7d4c68fA03b2cAf2A12B745fB6B8eC08Dd));

    function run() public {
        vm.startBroadcast();

        Vault_seth vaultImpl = new Vault_seth();
        vault.upgradeTo(address(vaultImpl));
    }
}
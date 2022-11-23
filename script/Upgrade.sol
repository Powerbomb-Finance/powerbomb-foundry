// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/PengTogether.sol";
import "../src/Vault_seth.sol";
// import "../src/Record.sol";
// import "../src/Record_eth.sol";
// import "../src/Reward.sol";
// import "../src/Dao.sol";
// import "../src/PengHelperEth.sol";
// import "../src/PengHelperOp.sol";

contract Upgrade is Script {
    PengTogether vault = PengTogether(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614));
    Vault_seth vault_seth = Vault_seth(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    // Record record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d);
    // Record_eth record_eth = Record_eth(0xC530677144A7EA5BaE6Fbab0770358522b4e7071);
    // FarmCurve farm = FarmCurve(payable(0xA6cFCa9EB181728082D35419B58Ba7eE4c9c8d38));
    // Reward reward = Reward(payable(0xc052Ac7d4c68fA03b2cAf2A12B745fB6B8eC08Dd));
    // Dao dao = Dao(0x0C9133Fa96d72C2030D63B6B35c3738D6329A313);
    // PengHelperEth pengHelperEth = PengHelperEth(payable(0x8afa0A68a7FD536f44B474DeBC93825b9De2ED43));
    // PengHelperOp pengHelperOp = PengHelperOp(payable(0xF0271d3A0fb34ca3DB507C61ED54753D46E686e8));

    function run() public {
        vm.startBroadcast();

        PengTogether vaultImpl = new PengTogether();
        vault.upgradeToAndCall(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("setHelper(address)")),
                0xCf91CDBB4691a4b912928A00f809f356c0ef30D6
            )
        );

        Vault_seth vault_sethImpl = new Vault_seth();
        vault_seth.upgradeToAndCall(
            address(vault_sethImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("setHelper(address)")),
                0xCf91CDBB4691a4b912928A00f809f356c0ef30D6
            )
        );

        // Record recordImpl = new Record();
        // record.upgradeTo(address(recordImpl));

        // Record_eth record_ethImpl = new Record_eth();
        // record_eth.upgradeTo(address(record_ethImpl));

        // Dao daoImpl = new Dao();
        // dao.upgradeToAndCall(
        //     address(daoImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("setTrustedRemote(uint16,address)")),
        //         111,
        //         address(record)
        //     )
        // );

        // PengHelperEth pengHelperEthImpl = new PengHelperEth();
        // pengHelperEth.upgradeTo(address(pengHelperEthImpl));

        // PengHelperOp pengHelperOpImpl = new PengHelperOp();
        // pengHelperOp.upgradeTo(address(pengHelperOpImpl));
    }
}
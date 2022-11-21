// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
// import "../src/PengTogether.sol";
// import "../src/Vault_seth.sol";
import "../src/Record.sol";
import "../src/Record_eth.sol";
// import "../src/Reward.sol";
// import "../src/Dao.sol";
// import "../src/PengHelperEth.sol";
// import "../src/PengHelperOp.sol";

contract Upgrade is Script {
    // PengTogether vault = PengTogether(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    // Vault_seth vault = Vault_seth(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    Record record = Record(0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d);
    Record_eth record_eth = Record_eth(0xC530677144A7EA5BaE6Fbab0770358522b4e7071);
    // FarmCurve farm = FarmCurve(payable(0xA6cFCa9EB181728082D35419B58Ba7eE4c9c8d38));
    // Reward reward = Reward(payable(0xc052Ac7d4c68fA03b2cAf2A12B745fB6B8eC08Dd));
    // Dao dao = Dao(0x0C9133Fa96d72C2030D63B6B35c3738D6329A313);
    // PengHelperEth pengHelperEth = PengHelperEth(payable(0xb8207E293F9D8CCc3966061b1253F1be65e1972B));
    // PengHelperOp pengHelperOp = PengHelperOp(0xD185782927EC7a443ecDA8d513AF666108A2Bd32);

    function run() public {
        vm.startBroadcast();

        Record recordImpl = new Record();
        record.upgradeTo(address(recordImpl));

        Record_eth record_ethImpl = new Record_eth();
        record_eth.upgradeTo(address(record_ethImpl));

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
    }
}
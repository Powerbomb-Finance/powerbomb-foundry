// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/PengTogether.sol";
import "../src/FarmCurve.sol";
import "../src/Reward.sol";

contract Upgrade is Script {
    PengTogether vault = PengTogether(0x1EFB578eCe71D99f5994a79815aA09A8f87F7429);
    FarmCurve farm = FarmCurve(payable(0xA6cFCa9EB181728082D35419B58Ba7eE4c9c8d38));
    Reward reward = Reward(payable(0xc052Ac7d4c68fA03b2cAf2A12B745fB6B8eC08Dd));

    function run() public {
        vm.startBroadcast();

        PengTogether vaultImpl = new PengTogether();
        vault.upgradeTo(address(vaultImpl));
    }
}

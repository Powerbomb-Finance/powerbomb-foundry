// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "../src/PengTogether.sol";
import "../src/FarmCurve.sol";
import "../src/Reward.sol";
import "../src/PbProxy.sol";

contract Deploy is Script {

    function run() public {
        vm.startBroadcast();

        // FarmCurve farm = new FarmCurve();
        // PbProxy farmProxy = new PbProxy(
        //     address(farm),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // farm = FarmCurve(payable(address(farmProxy)));
        // console.log("farm:", address(farm));

        // PengTogether vault = new PengTogether();
        // PbProxy vaultProxy = new PbProxy(
        //     address(vault),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         address(farm)
        //     )
        // );
        // vault = PengTogether(address(vaultProxy));
        // console.log("vault:", address(vault));

        // farm.setVault(address(vault));


        address pengTogetherVault = 0x1EFB578eCe71D99f5994a79815aA09A8f87F7429;
        uint64 subscriptionId = 22001;
        Reward reward = new Reward();
        PbProxy rewardProxy = new PbProxy(
            address(reward),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,uint64)")),
                pengTogetherVault,
                subscriptionId
            )
        );
        reward = Reward(payable(address(rewardProxy)));
        console.log("reward:", address(reward));

        FarmCurve farm = FarmCurve(payable(0xA6cFCa9EB181728082D35419B58Ba7eE4c9c8d38));
        farm.setReward(address(reward));
    }
}

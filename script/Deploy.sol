// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "src/PbUniV3Op.sol";
import "src/PbUniV3OpReward.sol";
import "src/PbProxy.sol";

contract Deploy is Script {

    function run() public {
        vm.startBroadcast();

        // Deploy vault
        PbUniV3Op vault = new PbUniV3Op();
        PbProxy vaultProxy = new PbProxy(
            address(vault),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                0xbf16ef186e715668AA29ceF57e2fD7f9D48AdFE6, // _uniswapV3Pool, USDC/DAI
                msg.sender // _bot
            )
        );
        vault = PbUniV3Op(address(vaultProxy));

        // Deploy reward
        PbUniV3OpReward reward = new PbUniV3OpReward();
        PbProxy rewardProxy = new PbProxy(
            address(reward),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,uint256,address)")),
                address(vault), // _vault
                500, // _yieldFeePerc
                msg.sender // _treasury
            )
        );
        reward = PbUniV3OpReward(address(rewardProxy));

        // Vault set reward contract
        vault.setReward(IReward(address(reward)));
    }
}

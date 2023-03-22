// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/PbVelo.sol";
import "forge-std/Script.sol";

contract Upgrade is Script {

    function run() public {
        vm.startBroadcast();

        PbVelo vaultImpl = new PbVelo();
        PbVelo vault;

        // vault = PbVelo(payable(0x208e2D48b5A080E57792D8b175De914Ddb18F9a8));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xee9857e5e1d0089075F75ABe5255fc30695d09FA));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x74f6C748E2DF1c89bf7ed29617A2B41b0f4f82A2));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x75633BFAbf0ee9036af06900b8f301Ed8ed29121));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xc23CF2762094a4Dd8DC3D4AaAAfdB38704B0f484));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xC15d58452E7CC62F213534dcD1999EDcc4C56E53));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xcaCdE37C8Aef43304e9d7153e668eDb7126Ff755));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xf12a8E2Fd857B134381c1B9F6027D4F0eE05295A));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x52671440732589E3027517E22c49ABc04941CF2F));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x3BD8d78d77dfA391c5F73c10aDeaAdD9a7f7198C));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x2510E5054eeEbED40C3C580ae3241F5457b630D9));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xFAcB839BF8f09f2e7B4b6C83349B5bbFD62fd659));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x176CC5Ff9BDBf4daFB955003E6f8229f47Ef1E55));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xa0Ea9A553cB47658e62Dee4D7b49F7c8Da234B69));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0xd0f9990a611018b5b30BFE1C5433bf5bba2a9868));
        // vault.upgradeTo(address(vaultImpl));

        // vault = PbVelo(payable(0x0F0fFF5EA56b0eA2246A926F13181e33Be9FbAEA));
        // vault.upgradeTo(address(vaultImpl));

        vault = PbVelo(payable(0xcba7864134e1A5326b817676ad5302A009c84d68));
        vault.upgradeTo(address(vaultImpl));
    }
}

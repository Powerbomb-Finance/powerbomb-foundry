// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PengTogether is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    function initialize() external initializer {
        __Ownable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
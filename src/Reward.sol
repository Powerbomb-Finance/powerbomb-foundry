// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Reward is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    receive() external payable {}
    
    function _authorizeUpgrade(address) internal override onlyOwner {}
}

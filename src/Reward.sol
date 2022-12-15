// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "../interface/ILSSVMRouter.sol";
import "../interface/ISudoPool.sol";

/// @title contract to buy nft from sudoswap and transfer to dao contract
/// @author siew
contract Reward is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    ILSSVMRouter constant ROUTER = ILSSVMRouter(0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329); // sudoswap

    // to set peng together contract address on optimism, unused now due to eth from stargate
    // can receive directly in this contract without stargate sgReceive
    mapping(uint16 => bytes) public trustedRemoteLookup;
    address public admin;
    address public dao;
    uint public nftSwapped;

    event BuyNFT(address pool, uint NFTPrice);
    event SetAdmin(address admin_);
    event SetDao(address dao_);

    function initialize(address dao_) external initializer {
        require(dao_ != address(0), "address 0");
        __Ownable_init();

        dao = dao_;
        admin = msg.sender;
    }

    /// @notice to receive eth send from stargate router
    receive() external payable {}

    /// @notice buy nft and send to dao contract
    /// @dev make sure eth in this contract > floor price of nft
    /// @param pool sudoswap pool to buy nft
    function buyNFT(address pool) external {
        require(msg.sender == admin || msg.sender == owner(), "only authorized");
        nftSwapped += 1;

        ILSSVMRouter.PairSwapAny[] memory swapList = new ILSSVMRouter.PairSwapAny[](1);
        swapList[0] = ILSSVMRouter.PairSwapAny(pool, 1);
        uint thisBalance = address(this).balance;
        uint remainingValue = ROUTER.swapETHForAnyNFTs{value: thisBalance}(
            swapList, // swapList
            payable(address(this)), // ethRecipient
            dao, // nftRecipient
            block.timestamp // deadline
        );

        emit BuyNFT(pool, thisBalance - remainingValue);
    }

    function setNftSwapped(uint nftSwapped_) external onlyOwner {
        nftSwapped = nftSwapped_;
    }

    /// @notice set new admin
    /// @param admin_ new admin address
    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "address 0");
        admin = admin_;

        emit SetAdmin(admin_);
    }

    /// @notice set new dao contract
    /// @param dao_ new dao contract address
    function setDao(address dao_) external onlyOwner {
        require(dao_ != address(0), "address 0");
        dao = dao_;

        emit SetDao(dao_);
    }

    /// @notice get pool with floor price from input pools
    /// @param pools pool list to query
    /// @param nft nft to query
    /// @return floorPrice floor price of the selected pool
    /// @return poolWithFloorPrice pool selected with floor price
    function getPoolWithFloorPrice(
        address[] calldata pools,
        address nft
    ) external view returns (uint floorPrice, address poolWithFloorPrice) {
        for (uint i = 0; i < pools.length; i++) {
            ISudoPool pool = ISudoPool(pools[i]);
            if (IERC721Upgradeable(nft).balanceOf(address(pool)) > 0) {
                // fetch price of the pool
                (,,, uint inputAmount,) = pool.getBuyNFTQuote(1);
                if (floorPrice == 0) {
                    // first pool
                    floorPrice = inputAmount;
                    poolWithFloorPrice = address(pool);
                } else {
                    if (inputAmount < floorPrice) {
                        // current pool floor price is lower than previous floor price
                        // update current pool floor price and pool address
                        floorPrice = inputAmount;
                        poolWithFloorPrice = address(pool);
                    }
                }
            }
        }
    }

    /// @dev for uups upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
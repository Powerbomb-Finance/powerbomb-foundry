// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";

import "../interface/ILSSVMRouter.sol";
import "../interface/ISudoPool.sol";

contract Reward is
    Initializable, 
    OwnableUpgradeable,
    UUPSUpgradeable
{
    ILSSVMRouter constant ROUTER = ILSSVMRouter(0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329); // sudoswap

    mapping(uint16 => bytes) public trustedRemoteLookup; // PengTogether contract on Optimism
    address public admin;
    address public dao;
    uint public nftSwapped;

    event BuyNFT(address pool, uint NFTPrice);
    event SetTrustedRemoteLookup(uint16 chainId, address trustedRemote);
    event SetAdmin(address admin_);
    event SetDao(address dao_);

    function initialize(address dao_, address pengTogetherVault) external initializer {
        require(dao_ != address(0), "address 0");
        __Ownable_init();

        trustedRemoteLookup[111] = abi.encodePacked(pengTogetherVault);

        dao = dao_;
        admin = msg.sender;
    }

    receive() external payable {}

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

    function setTrustedRemoteLookup(uint16 chainId, address trustedRemote) external onlyOwner {
        trustedRemoteLookup[chainId] = abi.encodePacked(trustedRemote);

        emit SetTrustedRemoteLookup(chainId, trustedRemote);
    }

    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "address 0");
        admin = admin_;

        emit SetAdmin(admin_);
    }

    function setDao(address dao_) external onlyOwner {
        require(dao_ != address(0), "address 0");
        dao = dao_;

        emit SetDao(dao_);
    }

    function getPoolWithFloorPrice(
        address[] calldata pools,
        address nft
    ) external view returns (uint floorPrice, address poolWithFloorPrice) {
        for (uint i = 0; i < pools.length; i++) {
            ISudoPool pool = ISudoPool(pools[i]);
            if (IERC721(nft).balanceOf(address(pool)) > 0) {
                (,,, uint inputAmount,) = pool.getBuyNFTQuote(1);
                if (floorPrice == 0) {
                    floorPrice = inputAmount;
                    poolWithFloorPrice = address(pool);
                } else {
                    if (inputAmount < floorPrice) {
                        floorPrice = inputAmount;
                        poolWithFloorPrice = address(pool);
                    }
                }
            }
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
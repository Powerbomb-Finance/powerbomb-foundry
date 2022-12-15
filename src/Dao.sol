// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/VRFConsumerBaseV2.sol";

import "../interface/ILayerZeroReceiver.sol";
import "../interface/ILayerZeroEndpoint.sol";

/// @title contract to request random seat & distribute nft
/// @dev to inherit VRFConsumerBaseV2 need constructor argument address _vrfCoordinator
/// @author siew
contract Dao is
    Initializable, 
    OwnableUpgradeable,
    UUPSUpgradeable,
    ILayerZeroReceiver,
    IERC721ReceiverUpgradeable,
    VRFConsumerBaseV2(0x271682DEB8C4E0901D1a1550aD2e64D568E69909)
{
    ILayerZeroEndpoint constant LZ_ENDPOINT = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
    mapping(uint16 => bytes) public trustedRemoteLookup; // record contract on Optimism

    // 200 gwei key hash for ethereum mainnet
    // refer https://docs.chain.link/vrf/v2/subscription/supported-networks#ethereum-mainnet
    bytes32 constant KEY_HASH = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
    address constant VRF_COORDINATOR = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    VRFCoordinatorV2Interface private coordinator;
    uint64 public subscriptionId;

    IERC721Upgradeable public nft;
    address public reward; // reward contract on ethereum, depreciated
    uint public totalSeats;
    bool public rngInProgress;
    uint public randomSeat;
    address public winner;

    event LzReceiveRetry(uint16 _srcChainId, bytes _srcAddress, bytes _payload);
    event LzReceiveClear(uint16 _srcChainId, address _srcAddress);
    event DistributeNFT(address winner, address _nft, uint tokenId);
    event SetNft(address _nft);
    event SetTotalSeats(uint _totalSeats);
    event SetRandomSeat(uint _randomSeat);
    event SetWinner(address _winner);
    event SetTrustedRemote(uint16 chainId, address record);

    function initialize(address record, uint64 subscriptionId_, address nft_) external initializer {
        require(nft_ != address(0), "address 0");
        __Ownable_init();

        /// 111 is source chain id for optimism
        trustedRemoteLookup[111] = abi.encodePacked(record, address(this));
        nft = IERC721Upgradeable(nft_);

        coordinator = VRFCoordinatorV2Interface(VRF_COORDINATOR);
        subscriptionId = subscriptionId_;
    }

    /// @notice layerzero call this function which request from source contract
    /// @param srcChainId source chain id, 111 for optimism
    /// @param srcAddress_ source contract address + this contract address in bytes
    /// @param payload any data send from source contract
    function lzReceive(uint16 srcChainId, bytes calldata srcAddress_, uint64, bytes memory payload) override external {
        require(msg.sender == address(LZ_ENDPOINT), "sender != lzEndpoint");
        // cannot compare bytes directly so use keccak256
        require(keccak256(srcAddress_) == keccak256(trustedRemoteLookup[srcChainId]), "srcAddr != trustedRemote");
        
        // received payload either totalSeats_ != 0 or winner_ != address(0)
        (uint totalSeats_, address winner_) = abi.decode(payload, (uint, address));
        if (totalSeats_ != 0) {
            totalSeats = totalSeats_;
            emit SetTotalSeats(totalSeats_);
        }
        if (winner_ != address(0)) {
            winner = winner_;
            emit SetWinner(winner_);
        }
    }

    /// @notice retrieve any payload that didn't execute due to error, can view from layerzeroscan.com 
    /// @param srcChainId 111 for optimism
    /// @param srcAddress_ optimismRecordAddr
    /// @param payload abi.encode(totalSeats, address(0)) || abi.encode(0, winnerAddr)
    function lzReceiveRetry(uint16 srcChainId, address srcAddress_, bytes calldata payload) external {
        bytes memory srcAddress = abi.encodePacked(srcAddress_, address(this));
        emit LzReceiveRetry(srcChainId, srcAddress, payload);
        LZ_ENDPOINT.retryPayload(srcChainId, srcAddress, payload);
    }

    /// @notice clear any payload that block the subsequent payload
    /// @param srcChainId 111 for optimism
    /// @param srcAddress_ optimismRecordAddr
    function lzReceiveClear(uint16 srcChainId, address srcAddress_) external onlyOwner {
        bytes memory srcAddress = abi.encodePacked(srcAddress_, address(this));
        emit LzReceiveClear(srcChainId, srcAddress_);
        LZ_ENDPOINT.forceResumeReceive(srcChainId, srcAddress);
    }

    /// @notice request random number from chainlink
    /// @notice this function can called by anyone
    /// @dev link token deduct from chainlink subscription contract with subscription id above
    function requestRandomWords() external {
        require(totalSeats != 0, "totalSeats == 0");
        require(randomSeat == 0, "randomSeat != 0");
        require(!rngInProgress, "rng in progress");

        // to prevent this function called twice while waiting for chainlink feedback
        rngInProgress = true;

        uint requestId = coordinator.requestRandomWords(
            KEY_HASH, // keyHash
            subscriptionId, // subscriptionId
            3, // requestConfirmations
            100_000, // callBackGasLimit
            1 // numWords
        );
        require(requestId > 0);
    }

    /// @notice set random seat by chainlink vrf coordinator
    /// @inheritdoc VRFConsumerBaseV2
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // only request 1 random word
        uint randomNumber = randomWords[0];
        // randomNumber is a very big number, modulus by totalSeats
        // will get a number between 0 and totalSeats - 1
        randomSeat = randomNumber % totalSeats;
        rngInProgress = false;

        emit SetRandomSeat(randomSeat);
    }

    /// @notice distribute nft to the winner
    /// @notice this function can called by anyone
    function distributeNFT(uint tokenId) external {
        address winner_ = winner;
        require(winner_ != address(0), "winner == address(0)");

        // reset everything
        winner = address(0);
        randomSeat = 0;
        totalSeats = 0;

        // transfer nft to winner
        nft.transferFrom(address(this), winner_, tokenId);
        emit DistributeNFT(winner_, address(nft), tokenId);
    }

    /// @notice set new nft
    /// @param nft_ new nft contract address
    function setNft(address nft_) external onlyOwner {
        require(nft_ != address(0), "address 0");
        nft = IERC721Upgradeable(nft_);

        emit SetNft(nft_);
    }

    /// @notice set total seats manually by owner
    /// @dev only use this function if layerzero failed
    /// @param totalSeats_ total seats
    function setTotalSeats(uint totalSeats_) external onlyOwner {
        totalSeats = totalSeats_;

        emit SetTotalSeats(totalSeats_);
    }

    /// @notice set winner manually by owner
    /// @dev only use this function if layerzero failed
    /// @param winner_ winner address
    function setWinner(address winner_) external onlyOwner {
        require(winner_ != address(0), "address 0");
        winner = winner_;

        emit SetWinner(winner_);
    }

    /// @notice set new chain id or new record contract address
    /// @param chainId new chain id
    /// @param record new record contract address
    function setTrustedRemote(uint16 chainId, address record) external onlyOwner {
        trustedRemoteLookup[chainId] = abi.encodePacked(record, address(this));

        emit SetTrustedRemote(chainId, record);
    }

    /// @notice function to receive erc721 if sender use safeTransferFrom
    /// @dev all arguments passed into this function are unused
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev for uups upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
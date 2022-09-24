// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/VRFConsumerBaseV2.sol";

import "../interface/ILayerZeroReceiver.sol";
import "../interface/ILSSVMRouter.sol";

contract Reward is
    Initializable, 
    OwnableUpgradeable,
    UUPSUpgradeable,
    ILayerZeroReceiver,
    VRFConsumerBaseV2(0x271682DEB8C4E0901D1a1550aD2e64D568E69909)
{
    ILayerZeroReceiver constant lzEndpoint = ILayerZeroReceiver(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
    mapping(uint16 => bytes) public trustedRemoteLookup; // PengTogether contract on Optimism
    uint public totalSeats;
    address public winner;

    address constant vrfCoordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    VRFCoordinatorV2Interface private COORDINATOR;
    uint64 public s_subscriptionId;
    uint public randomSeat;

    ILSSVMRouter constant router = ILSSVMRouter(0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329); // sudoswap
    address public admin;

    event BuyNFTAndRewardWinner(address pool, uint NFTPrice, address rewardedWinner);
    event SetRandomSeat(uint _randomSeat);
    event SetTotalSeats(uint _totalSeats);
    event SetWinner(address _winner);
    event SetAdmin(address _admin);
    event SetTrustedRemoteLookup(uint16 chainId, address trustedRemote);

    modifier onlyAuthorized {
        require(msg.sender == admin || msg.sender == owner(), "only authorized");
        _;
    }

    function initialize(address pengTogetherVault, uint64 subscriptionId) external initializer {
        __Ownable_init();

        trustedRemoteLookup[111] = abi.encodePacked(pengTogetherVault);

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        admin = msg.sender;
    }

    receive() external payable {}

    function buyNFTAndRewardWinner(address pool) external onlyAuthorized {
        require(winner != address(0), "winner is zero address");

        ILSSVMRouter.PairSwapAny[] memory swapList = new ILSSVMRouter.PairSwapAny[](1);
        swapList[0] = ILSSVMRouter.PairSwapAny(pool, 1);
        uint thisBalance = address(this).balance;
        uint remainingValue = router.swapETHForAnyNFTs{value: thisBalance}(
            swapList, // swapList
            payable(address(this)), // ethRecipient
            winner, // nftRecipient
            block.timestamp // deadline
        );

        winner = address(0);
        randomSeat = 0;
        totalSeats = 0;

        emit BuyNFTAndRewardWinner(pool, thisBalance - remainingValue, winner);
    }

    // function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    //     return IERC721ReceiverUpgradeable.onERC721Received.selector;
    // }

    function requestRandomWords() external onlyAuthorized {
        // Will revert if subscription is not set and funded.
        COORDINATOR.requestRandomWords(
            0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef, // keyHash
            s_subscriptionId, // s_subscriptionId
            3, // requestConfirmations
            100000, // callBackGasLimit
            1 // numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint randomNumber = randomWords[0];
        randomSeat = randomNumber % totalSeats;

        emit SetRandomSeat(randomSeat);
    }

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64, bytes memory _payload) override external {
        require(msg.sender == address(lzEndpoint));
        require(keccak256(_srcAddress) == keccak256(trustedRemoteLookup[_srcChainId]));
        
        (uint _totalSeats, address _winner) = abi.decode(_payload, (uint, address));
        if (_totalSeats != 0 && winner == address(0)) {
            totalSeats = _totalSeats;
            emit SetTotalSeats(_totalSeats);
        } else {
            winner = _winner;
            emit SetWinner(_winner);
        }
    }

    ///@notice only use this function if layerzero failed
    function setTotalSeats(uint _totalSeats) external onlyAuthorized {
        totalSeats = _totalSeats;

        emit SetTotalSeats(_totalSeats);
    }

    ///@notice only use this function if layerzero failed
    function setWinner(address _winner) external onlyAuthorized {
        winner = _winner;

        emit SetWinner(_winner);
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    function setTrustedRemoteLookup(uint16 chainId, address trustedRemote) external onlyOwner {
        trustedRemoteLookup[chainId] = abi.encodePacked(trustedRemote);

        emit SetTrustedRemoteLookup(chainId, trustedRemote);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

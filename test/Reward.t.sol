// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../interface/ILSSVMRouter.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "../src/Reward.sol";
import "../src/PbProxy.sol";

contract RewardTest is Test {
    IERC721 lilPenguin = IERC721(0x524cAB2ec69124574082676e6F654a18df49A048);
    address pengTogetherVault = address(1);
    uint64 s_subscriptionId = 0;
    Reward reward;

    function setUp() public {
        reward = new Reward();
        PbProxy proxy = new PbProxy(
            address(reward),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,uint64)")),
                pengTogetherVault, // pengTogetherVault
                s_subscriptionId // subscriptionId
            )
        );
        reward = Reward(payable(address(proxy)));
    }

    function testAll() public {
        // assume receive eth from stargate
        (bool success,) = address(reward).call{value: 0.22 ether}("");
        require(success);

        // assume receive totalSeat from layerzero
        hoax(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
        bytes memory srcAddress = abi.encodePacked(pengTogetherVault);
        bytes memory data = abi.encode(1234, address(0));
        reward.lzReceive(111, srcAddress, uint64(0), data);
        assertEq(reward.totalSeats(), 1234);

        // assume get random number from chainlink
        hoax(0x271682DEB8C4E0901D1a1550aD2e64D568E69909);
        uint[] memory randomWords = new uint[](1);
        randomWords[0] = 12345678901234567;
        reward.rawFulfillRandomWords(0, randomWords);
        assertLt(reward.randomSeat(), 1234);

        // assume receive winner
        hoax(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
        data = abi.encode(0, address(2));
        reward.lzReceive(111, srcAddress, uint64(0), data);
        assertEq(reward.winner(), address(2));

        // assume buy nft and reward winner
        reward.buyNFTAndRewardWinner(0xd644eA091556e825660cd75945f1843d32b00cCe);
        assertEq(lilPenguin.balanceOf(address(2)), 1);
        assertEq(reward.totalSeats(), 0);
        assertEq(reward.winner(), address(0));
        assertEq(reward.randomSeat(), 0);
        assertGt(address(reward).balance, 0.01 ether);
    }

    function testGlobalVariable() public {
        assertEq(reward.trustedRemoteLookup(111), abi.encodePacked(pengTogetherVault));
        assertEq(reward.totalSeats(), 0);
        assertEq(reward.winner(), address(0));
        assertEq(reward.s_subscriptionId(), s_subscriptionId);
        assertEq(reward.randomSeat(), 0);
        assertEq(reward.admin(), address(this));
    }

    function testSetter() public {
        reward.setTotalSeats(6288);
        assertEq(reward.totalSeats(), 6288);
        reward.setWinner(address(6288));
        assertEq(reward.winner(), address(6288));
        reward.setAdmin(address(7707));
        assertEq(reward.admin(), address(7707));
        reward.setTrustedRemoteLookup(112, address(5));
        assertEq(reward.trustedRemoteLookup(112), abi.encodePacked(address(5)));
    }

    function testAuthorization() public {
        assertEq(reward.owner(), address(this));
        reward.setAdmin(address(2));
        reward.transferOwnership(address(1));
        vm.expectRevert("Initializable: contract is already initialized");
        reward.initialize(address(0), 0);
        vm.expectRevert("only authorized");
        reward.buyNFTAndRewardWinner(address(0));
        vm.expectRevert("only authorized");
        reward.requestRandomWords();
        vm.expectRevert();
        reward.lzReceive(0, abi.encodePacked(address(0)), 0, "");
        vm.expectRevert("only authorized");
        reward.setTotalSeats(0);
        vm.expectRevert("only authorized");
        reward.setWinner(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.setAdmin(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.setTrustedRemoteLookup(0, address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.upgradeTo(address(0));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../interface/ILSSVMRouter.sol";
// import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "../src/Dao.sol";
import "../src/Reward.sol";
import "../src/PbProxy.sol";

interface IERC721Modified is IERC721 {
    function walletOfOwner(address owner) external view returns (uint[] memory);
}

contract RewardTest is Test {
    IERC721Modified lilPudgy = IERC721Modified(0x524cAB2ec69124574082676e6F654a18df49A048);
    address pengTogetherVault = 0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250;
    address record = 0xC530677144A7EA5BaE6Fbab0770358522b4e7071;
    uint64 s_subscriptionId = 414;
    Reward reward;
    Dao dao;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        // PbProxy proxy;
        // dao = new Dao();
        // proxy = new PbProxy(
        //     address(dao),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,uint64,address)")),
        //         record,
        //         s_subscriptionId, // subscriptionId,
        //         address(lilPudgy)
        //     )
        // );
        // dao = Dao(address(proxy));
        dao = Dao(0x0C9133Fa96d72C2030D63B6B35c3738D6329A313);
        // Dao daoImpl = new Dao();
        // hoax(owner);
        // dao.upgradeToAndCall(
        //     address(daoImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("setTrustedRemote(uint16,address)")),
        //         111,
        //         record
        //     )
        // );

        // reward = new Reward();
        // proxy = new PbProxy(
        //     address(reward),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         address(dao),
        //         pengTogetherVault // pengTogetherVault
        //     )
        // );
        // reward = Reward(payable(address(proxy)));
        reward = Reward(payable(address(0xB7957FE76c2fEAe66B57CF3191aFD26d99EC5599)));

        // dao.setReward(address(reward));
    }

    // function test() public {
    //     // hoax(owner);
    //     // dao.setTrustedRemote(111, record);

    //     // hoax(owner);
    //     // dao.lzReceiveClear(111, record);

    //     hoax(owner);
    //     dao.lzReceiveRetry(
    //         111,
    //         // bytes("176B6AD5063BFFBCA9867DE6B3A1EB27A306E40D28BCC4202CD179499BF618DBFD1BFE37278E1A12"),
    //         abi.encodePacked(record, address(dao)),
    //         abi.encode(398657, address(0))
    //     );
    //     // console.log(dao.totalSeats());
    // }

    function testAll() public {
        // assume receive eth from stargate to reward
        (bool success,) = address(reward).call{value: 0.4 ether}("");
        require(success);

        // try call requestRandomWords() before set totalSeats
        vm.expectRevert("totalSeats == 0");
        dao.requestRandomWords();

        // assume receive totalSeat from layerzero
        hoax(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
        bytes memory srcAddress = abi.encodePacked(record, address(dao));
        bytes memory data = abi.encode(1234, address(0));
        dao.lzReceive(111, srcAddress, uint64(0), data);
        assertEq(dao.totalSeats(), 1234);

        // assume get random number from chainlink
        dao.requestRandomWords(); // will revert if subscription is not set and funded
        // try call requestRandomWords() again after call requestRandomWords() before call fulfillRandomWords()
        vm.expectRevert("rng in progress");
        dao.requestRandomWords();
        hoax(0x271682DEB8C4E0901D1a1550aD2e64D568E69909);
        uint[] memory randomWords = new uint[](1);
        randomWords[0] = 12345678901234567;
        dao.rawFulfillRandomWords(0, randomWords);
        assertLt(dao.randomSeat(), 1234);

        // try call distributeNFT() before winner set
        vm.expectRevert("winner == address(0)");
        dao.distributeNFT(0);

        // try call requestRandomWords() again after randomSeat is set
        vm.expectRevert("randomSeat != 0");
        dao.requestRandomWords();

        // assume receive winner from layerzero
        hoax(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
        data = abi.encode(0, address(3));
        dao.lzReceive(111, srcAddress, uint64(0), data);
        assertEq(dao.winner(), address(3));

        // buy nft and transfer to dao
        // console.log(address(reward).balance); // 0.220000000000000000
        address[] memory pools = new address[](5);
        pools[0] = 0xd112Eb8c7bf465C2f3f3972994CaF016B094db42;
        pools[1] = 0xdE0fe89C598506c7a84a74dfAda640634371D6C5;
        pools[2] = 0x4d9BbA8cA9e1D171D73552Df22A56424B49Ee9de;
        pools[3] = 0xA28f7538dfc12Ba2188a96C35Aa7B01B7307Bc34;
        pools[4] = 0xd644eA091556e825660cd75945f1843d32b00cCe;
        (uint floorPrice, address poolWithFloorPrice) = reward.getPoolWithFloorPrice(
            pools,
            address(lilPudgy)
        );
        // console.log(floorPrice); // 0.205880000000000028
        // console.log(poolWithFloorPrice); // 0xd644ea091556e825660cd75945f1843d32b00cce
        assertLe(floorPrice, address(reward).balance);
        assertEq(poolWithFloorPrice != address(0), true);
        hoax(owner);
        reward.buyNFT(poolWithFloorPrice);
        // reward.buyNFT(0xd644eA091556e825660cd75945f1843d32b00cCe);
        assertEq(lilPudgy.balanceOf(address(reward)), 0);
        assertEq(lilPudgy.balanceOf(address(dao)), 1);
        // console.log(address(reward).balance); // 0.014119999999999972

        // distribute nft
        // assume get lil pudgy with tokenId 4
        hoax(0x4BE3CC27Ec18a1DC1175a59B14C7857E579225BF);
        lilPudgy.transferFrom(0x4BE3CC27Ec18a1DC1175a59B14C7857E579225BF, address(dao), 4);
        // uint[] memory tokenIds = lilPudgy.walletOfOwner(address(dao)); // spend to much time to load
        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 4;
        dao.distributeNFT(tokenIds[0]);
        assertEq(lilPudgy.balanceOf(address(3)), 1);
        assertEq(dao.totalSeats(), 0);
        assertEq(dao.winner(), address(0));
        assertEq(dao.randomSeat(), 0);

        // try call requestRandomWords() again after draw end before new totalSeat is set
        vm.expectRevert("totalSeats == 0");
        dao.requestRandomWords();

        // try call distributeNFT() again after draw end before new winner is set
        vm.expectRevert("winner == address(0)");
        dao.distributeNFT(0);
    }

    function testGlobalVariable() public {
        // reward
        assertEq(reward.trustedRemoteLookup(111), abi.encodePacked(pengTogetherVault));
        assertEq(reward.admin(), owner);
        assertEq(reward.dao(), address(dao));

        // dao
        assertEq(dao.trustedRemoteLookup(111), abi.encodePacked(record, address(dao)));
        assertEq(dao.s_subscriptionId(), s_subscriptionId);
        assertEq(address(dao.nft()), address(lilPudgy));
        assertEq(dao.reward(), address(reward));
        assertEq(dao.totalSeats(), 0);
        assertEq(dao.rngInProgress(), false);
        assertEq(dao.randomSeat(), 0);
        assertEq(dao.winner(), address(0));
    }

    function testSetter() public {
        // reward
        startHoax(owner);
        reward.setTrustedRemoteLookup(111, address(5));
        assertEq(reward.trustedRemoteLookup(111), abi.encodePacked(address(5)));
        reward.setAdmin(address(7707));
        assertEq(reward.admin(), address(7707));
        reward.setDao(address(7707));
        assertEq(reward.dao(), address(7707));

        // dao
        dao.setNft(address(6288));
        assertEq(address(dao.nft()), address(6288));
        dao.setReward(address(6288));
        assertEq(address(dao.reward()), address(6288));
        dao.setTotalSeats(6288);
        assertEq(dao.totalSeats(), 6288);
        dao.setWinner(address(6288));
        assertEq(dao.winner(), address(6288));
        dao.setTrustedRemote(111, address(5));
        assertEq(dao.trustedRemoteLookup(111), abi.encodePacked(address(5), address(dao)));
    }

    function testAuthorization() public {
        // reward
        assertEq(reward.owner(), owner);
        vm.startPrank(owner);
        reward.setAdmin(address(2));
        reward.transferOwnership(address(1));
        vm.stopPrank();
        vm.expectRevert("Initializable: contract is already initialized");
        reward.initialize(address(0), address(0));
        vm.expectRevert("only authorized");
        reward.buyNFT(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.setTrustedRemoteLookup(0, address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.setAdmin(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.setDao(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        reward.upgradeTo(address(0));

        // dao
        assertEq(dao.owner(), owner);
        hoax(owner);
        dao.transferOwnership(address(1));
        vm.expectRevert("Initializable: contract is already initialized");
        dao.initialize(address(0), 0, address(0));
        vm.expectRevert("sender != lzEndpoint");
        dao.lzReceive(0, abi.encodePacked(address(0), address(dao)), 0, "");
        vm.expectRevert("Ownable: caller is not the owner");
        dao.setNft(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        dao.setReward(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        dao.setTotalSeats(0);
        vm.expectRevert("Ownable: caller is not the owner");
        dao.setWinner(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        dao.upgradeTo(address(0));
    }

    receive() external payable {}
}

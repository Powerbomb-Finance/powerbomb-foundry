// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/PengHelperEth.sol";
import "../src/PbProxy.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interface/IQuoter.sol";

contract PengHelperEthTest is Test {
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable sgEth = IERC20Upgradeable(0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c);
    IQuoter sgQuoter = IQuoter(0x8731d54E9D02c286767d56ac03e8037C07e01e98); // stargate router ethereum
    // IQuoter sgQuoter = IQuoter(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b); // stargate router optimism
    IQuoter lzQuoter = IQuoter(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675); // layerzero endpoint
    address pengHelperOp = 0xCf91CDBB4691a4b912928A00f809f356c0ef30D6;
    // address owner = address(this);
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    PengHelperEth helper;

    function setUp() public {
        // PbProxy proxy;
        // helper = new PengHelperEth();
        // proxy = new PbProxy(
        //     address(helper),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address)")),
        //         pengHelperOp
        //     )
        // );
        // helper = PengHelperEth(payable(address(proxy)));
        helper = PengHelperEth(payable(0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab));
        PengHelperEth helperImpl = new PengHelperEth();
        hoax(owner);
        helper.upgradeTo(address(helperImpl));
    }


    function testDeposit() public {
        uint fee;

        // deposit eth
        (fee,) = sgQuoter.quoteLayerZeroFee(
            111, 1, abi.encodePacked(pengHelperOp),
            abi.encode(address(this), address(weth), 0.99 ether),
            IQuoter.lzTxObj(600000, 0, "0x")
        );
        // console.log(fee); // 0.001821656141483913
        helper.deposit{value: 1 ether + fee}(weth, 1 ether, 0.99 ether, 600000);

        // deposit usdc
        (fee,) = sgQuoter.quoteLayerZeroFee(
            111, 1, abi.encodePacked(pengHelperOp),
            abi.encode(address(this), address(usdc), 99e6),
            IQuoter.lzTxObj(600000, 0, "0x")
        );
        // console.log(fee); // 0.001821656141483913
        deal(address(usdc), address(this), 100e6);
        usdc.approve(address(helper), 100e6);
        helper.deposit{value: fee}(usdc, 100e6, 99e6, 600000);

        // assertion check
        assertEq(usdc.balanceOf(address(helper)), 0);
        assertEq(address(helper).balance, 0);
        assertEq(sgEth.balanceOf(address(helper)), 0);
    }

    function testWithdraw() public {
        testDeposit();

        // withdraw eth
        // estimate gas fee for bridge tokens from optimism to ethereum
        // (after message sent from ethereum to optimism)
        // this estimation should retrieve by sgQuoter optimism
        // here use sgQuoter ethereum for testing purpose
        (uint nativeForDst,) = sgQuoter.quoteLayerZeroFee(
            101, 1, abi.encodePacked(address(helper)), bytes(""),
            IQuoter.lzTxObj(0, 0, "0x")
        );
        // estimate gas fee for send message from ethereum to optimism
        (uint fee,) = lzQuoter.estimateFees(
            111, address(helper),
            abi.encode(address(weth), 1 ether, 0.99 ether, address(this)),
            false,
            abi.encodePacked(uint16(2), uint(1000000), nativeForDst, pengHelperOp)
        );
        // console.log(fee); // 0.009587028264829213
        // console.log(nativeForDst); // 0.006221784869021456
        helper.withdraw{value: fee}(weth, 1 ether, 0.99 ether, 1000000, nativeForDst);

        // withdraw usdc
        (fee,) = lzQuoter.estimateFees(
            111, address(helper),
            abi.encode(address(usdc), 100e6, 99e6, address(this)),
            false,
            abi.encodePacked(uint16(2), uint(1000000), nativeForDst, pengHelperOp)
        );
        // console.log(fee); // 0.009587028264829213
        helper.withdraw{value: fee}(usdc, 100e6, 99e6, 1000000, nativeForDst);
    }

    function testPauseContract() public {
        helper.pauseContract();
        vm.expectRevert("Pausable: paused");
        helper.deposit(weth, 0, 0, 0);
        helper.unPauseContract();
        helper.deposit{value: 1.1 ether}(weth, 1 ether, 0, 0);
    }

    function testArgRequire() public {
        vm.expectRevert("weth or usdc only");
        helper.deposit(IERC20Upgradeable(address(0)), 0, 0, 0);
        vm.expectRevert("min 0.1 ether");
        helper.deposit(weth, 0, 0, 0);
        vm.expectRevert("msg.value < amount");
        helper.deposit(weth, 0.1 ether, 0, 0);
        vm.expectRevert("min $100");
        helper.deposit(usdc, 0, 0, 0);
        vm.expectRevert("weth or usdc only");
        helper.withdraw(IERC20Upgradeable(address(0)), 0, 0, 0, 0);
        vm.expectRevert("invalid amount");
        helper.withdraw(weth, 0, 0, 0, 0);
    }

    function testSetter() public {
        startHoax(owner);
        vm.expectRevert("0 address");
        helper.setPengHelperOp(address(0));
        helper.setPengHelperOp(address(2));
        assertEq(helper.pengHelperOp(), address(2));
    }

    function testGlobalVariable() public {
        assertEq(helper.pengHelperOp(), pengHelperOp);
    }

    function testAuthorization() public {
        assertEq(helper.owner(), owner);
        hoax(owner);
        helper.transferOwnership(address(1));

        vm.expectRevert("Initializable: contract is already initialized");
        helper.initialize(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        helper.setPengHelperOp(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        helper.pauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        helper.unPauseContract();
    }

    receive() external payable {}
}
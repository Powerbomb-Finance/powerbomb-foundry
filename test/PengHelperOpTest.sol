// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "forge-std/Test.sol";
import "../src/PengHelperOp.sol";
import "../src/PengTogether.sol";
import "../src/Vault_seth.sol";
import "../src/PbProxy.sol";
import "../interface/IQuoter.sol";

contract PengHelperOpTest is Test {
    IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable weth = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    address usdcEth = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address wethEth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    PengTogether vaultSusd = PengTogether(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614));
    PengTogether vaultSeth = PengTogether(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    address pengHelperEth = 0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address stargateRouter = 0xB0D502E938ed5f4df2E681fE6E419ff29631d62b;
    address lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    PengHelperOp helper;
    IQuoter sgQuoter = IQuoter(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b); // stargate router optimism

    function setUp() public {
        // PbProxy proxy;
        // helper = new PengHelperOp();
        // proxy = new PbProxy(
        //     address(helper),
        //     abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        // );
        // helper = PengHelperOp(payable(address(proxy)));
        helper = PengHelperOp(payable(0xCf91CDBB4691a4b912928A00f809f356c0ef30D6));
        // PengHelperOp helperImpl = new PengHelperOp();
        // hoax(owner);
        // helper.upgradeTo(address(helperImpl));
    }

    function testDepositUsdc() public {
        // assume receive usdc
        deal(address(usdc), address(helper), 100e6);

        bytes memory payload = abi.encode(address(this), address(usdcEth), 99e6);

        // assume call by stargate router
        hoax(stargateRouter);
        helper.sgReceive(uint16(101), bytes(""), 0, address(usdc), 100e6, payload);

        // assertion check
        assertEq(vaultSusd.getUserDepositBalance(address(this)), 100e6);
        assertEq(usdc.balanceOf(address(helper)), 0);
    }

    function testDepositEth() public {
        // assume receive eth
        hoax(address(helper), 1 ether);
        vm.stopPrank();

        bytes memory payload = abi.encode(address(this), address(wethEth), 0.99 ether);

        // assume call by stargate router
        hoax(stargateRouter);
        helper.sgReceive(uint16(101), bytes(""), 0, address(weth), 1 ether, payload);

        // assertion check
        assertEq(vaultSeth.getUserDepositBalance(address(this)), 1 ether);
        assertEq(address(helper).balance, 0);
    }

    function testWithdrawUsdc() public {
        testDepositUsdc();
        vm.roll(block.number + 1);

        // assume airdrop from ethereum peng helper
        (uint nativeForDst,) = sgQuoter.quoteLayerZeroFee(
            101, 1, abi.encodePacked(address(helper)), bytes(""),
            IQuoter.lzTxObj(0, 0, "0x")
        );
        (bool success_,) = payable(helper).call{value: nativeForDst}("");
        require(success_);

        bytes memory _srcAddress = abi.encodePacked(pengHelperEth, address(helper));
        bytes memory payload = abi.encode(usdcEth, 100e6, 99e6, address(this));

        // assume call by layerzero endpoint
        hoax(lzEndpoint);
        helper.lzReceive(101, _srcAddress, 0, payload);

        // assertion check
        assertEq(vaultSusd.getUserDepositBalance(address(this)), 0);
        assertEq(usdc.balanceOf(address(helper)), 0);
    }

    function testWithdrawEth() public {
        testDepositEth();
        vm.roll(block.number + 1);

        // assume airdrop from ethereum peng helper
        (uint nativeForDst,) = sgQuoter.quoteLayerZeroFee(
            101, 1, abi.encodePacked(address(helper)), bytes(""),
            IQuoter.lzTxObj(0, 0, "0x")
        );
        (bool success_,) = payable(helper).call{value: nativeForDst}("");
        require(success_);

        bytes memory payload = abi.encode(wethEth, 1 ether, 0.99 ether, address(this));
        bytes memory _srcAddress = abi.encodePacked(pengHelperEth, address(helper));

        // assume call by layerzero endpoint
        hoax(lzEndpoint);
        helper.lzReceive(101, _srcAddress, 0, payload);

        // assertion check
        assertEq(vaultSeth.getUserDepositBalance(address(this)), 0);
        assertEq(address(helper).balance, 0);
    }

    function testDepositOnBehalf() public {
        // deposit usdc
        deal(address(usdc), address(this), 100e6);
        usdc.approve(address(helper), type(uint).max);
        helper.depositOnBehalf(address(usdc), 100e6, 0, address(this));

        // deposit eth
        helper.depositOnBehalf{value: 1 ether}(address(weth), 1 ether, 0, address(this));

        // assertion check
        assertEq(vaultSusd.getUserDepositBalance(address(this)), 100e6);
        assertEq(vaultSeth.getUserDepositBalance(address(this)), 1 ether);
    }

    function testWithdrawStuck() public {
        // assume usdc & eth stuck in helper contract
        deal(address(usdc), address(helper), 1000e6);
        hoax(address(helper), 1 ether);

        // withdraw
        uint usdcAmtBef = usdc.balanceOf(owner);
        uint ethAmtBef = address(owner).balance;
        hoax(owner);
        helper.withdrawStuck();

        // assertion check
        assertEq(usdc.balanceOf(owner), usdcAmtBef + 1000e6);
        assertGt(address(owner).balance, ethAmtBef);
        assertEq(usdc.balanceOf(address(helper)), 0);
        assertEq(address(helper).balance, 0);
    }

    function testSetter() public {
        hoax(owner);
        helper.setPengHelperEth(address(6288));
        assertEq(helper.pengHelperEth(), address(6288));
        assertEq(helper.trustedRemoteLookup(101), abi.encodePacked(address(6288), address(helper)));
    }

    function testGlobalVar() public {
        assertEq(helper.trustedRemoteLookup(101), abi.encodePacked(pengHelperEth, address(helper)));
        assertEq(helper.pengHelperEth(), pengHelperEth);
    }

    function testAuth() public {
        vm.expectRevert("Initializable: contract is already initialized");
        helper.initialize();
        vm.expectRevert("only stargate router");
        helper.sgReceive(0, abi.encode(address(0)), 0, address(0), 0, bytes(""));
        vm.expectRevert("sender != lzEndpoint");
        helper.lzReceive(0, abi.encode(address(0)), 0, bytes(""));

        assertEq(helper.owner(), owner);
        hoax(owner);
        helper.transferOwnership(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        helper.pauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        helper.unPauseContract();
        vm.expectRevert("Ownable: caller is not the owner");
        helper.lzReceiveClear();
        vm.expectRevert("Ownable: caller is not the owner");
        helper.setPengHelperEth(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        helper.withdrawStuck();
        vm.expectRevert("Ownable: caller is not the owner");
        helper.approveParaswapTokenTransferProxy(address(0));
    }
}
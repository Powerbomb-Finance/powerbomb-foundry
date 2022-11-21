// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "forge-std/Test.sol";
import "../src/PengHelperOp.sol";
import "../src/PengTogether.sol";
import "../src/Vault_seth.sol";
import "../src/PbProxy.sol";

contract PengHelperOpTest is Test {
    address usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address weth = 0x4200000000000000000000000000000000000006;
    PengTogether vaultSusd = PengTogether(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614));
    PengTogether vaultSeth = PengTogether(payable(0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250));
    address pengHelperEth = address(1); // assume
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;
    address stargateRouter = 0xB0D502E938ed5f4df2E681fE6E419ff29631d62b;
    address lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    PengHelperOp helper;

    function setUp() public {
        PbProxy proxy;
        helper = new PengHelperOp();
        proxy = new PbProxy(
            address(helper),
            abi.encodeWithSelector(bytes4(keccak256("initialize()")))
        );
        helper = PengHelperOp(payable(address(proxy)));
        helper.setPengHelperEth(pengHelperEth);

        // temp
        PengTogether vaultSusdImpl = new PengTogether();
        startHoax(owner);
        vaultSusd.upgradeTo(address(vaultSusdImpl));
        vaultSusd.setHelper(address(helper));
        vm.stopPrank();

        // temp
        Vault_seth vaultSethImpl = new Vault_seth();
        startHoax(owner);
        vaultSeth.upgradeTo(address(vaultSethImpl));
        vaultSeth.setHelper(address(helper));
        vm.stopPrank();
    }

    function test() public {
        uint amountOutMin;
        bytes memory payload;
        bytes memory srcAddress = abi.encode(pengHelperEth);

        // deposit usdc
        // assume receive usdc
        deal(address(usdc), address(helper), 100e6);
        amountOutMin = 99e6;
        payload = abi.encode(address(this), address(usdc), amountOutMin);
        // assume call by stargate router
        hoax(stargateRouter);
        helper.sgReceive(uint16(101), srcAddress, 0, usdc, 100e6, payload);
        
        // deposit eth
        // assume receive eth
        (bool success,) = payable(helper).call{value: 1 ether}("");
        require(success);
        amountOutMin = 0.99 ether;
        payload = abi.encode(address(this), address(weth), amountOutMin);
        // assume call by stargate router
        hoax(stargateRouter);
        helper.sgReceive(uint16(101), srcAddress, 0, weth, 1 ether, payload);

        bytes memory _srcAddress = abi.encodePacked(pengHelperEth, address(helper));
        vm.roll(block.number + 1);

        // withdraw usdc
        // assume airdrop from ethereum peng helper
        (bool success_,) = payable(helper).call{value: 0.01 ether}("");
        require(success_);
        // assume call by layerzero endpoint
        payload = abi.encode(usdc, 100e6, 99e6, address(this));
        hoax(lzEndpoint);
        helper.lzReceive(101, _srcAddress, 0, payload);

        // withdraw eth, separate to individual test function because weird error by foundry
        // assume airdrop from ethereum peng helper from above
        // assume call by layerzero endpoint
        // payload = abi.encode(weth, 1 ether, 0.99 ether, address(this));
        // hoax(lzEndpoint);
        // helper.lzReceive(101, _srcAddress, 0, payload);
    }

    function testWithdrawEth() public {
        vaultSeth.deposit{value: 1 ether}(IERC20Upgradeable(weth), 1 ether, 0);

        // assume airdrop from ethereum peng helper
        (bool success_,) = payable(helper).call{value: 0.01 ether}("");
        require(success_);
        vm.roll(block.number + 1);

        bytes memory payload = abi.encode(weth, 1 ether, 0.99 ether, address(this));
        bytes memory _srcAddress = abi.encodePacked(pengHelperEth, address(helper));
        hoax(lzEndpoint);
        helper.lzReceive(101, _srcAddress, 0, payload);
    }
}
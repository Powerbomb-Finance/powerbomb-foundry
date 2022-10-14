// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../interface/IPool.sol";
import "../interface/IGauge.sol";
import "../interface/IBalancer.sol";
import "../interface/IAuraZap.sol";

import "../src/Aura.sol";

contract AuraTest is Test {

    IERC20 lpToken = IERC20(0x3dd0843A028C86e0b760b1A76929d1C5Ef93a2dd);
    IPool pool = IPool(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
    IGauge gauge = IGauge(0x2AEF2f950E507A23cc19a882DC9b33c03B55D3f2);
    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAuraZap zap = IAuraZap(0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59);
    IERC20 bal = IERC20(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20 aura = IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 balWeth = IERC20(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
    IERC20 auraBAL = IERC20(0x616e8BfA43F920657B3497DBf40D6b1A02D4608d);
    uint pid = 19;

    Aura vault;
    
    function setUp() public {
        // lpToken.approve(address(pool), type(uint).max);
        // bal.approve(address(pool), type(uint).max);
        // aura.approve(address(pool), type(uint).max);
        // bal.approve(address(balancer), type(uint).max);
        // aura.approve(address(balancer), type(uint).max);
        // balWeth.approve(address(zap), type(uint).max);

        vault = new Aura();
    }

    // function testExample() public {
    //     uint amount = 10_000 ether;
    //     deal(address(lpToken), address(this), amount);
    //     pool.deposit(pid, amount, true);
    //     // console.log(gauge.balanceOf(address(this)));

    //     skip(864000);
    //     gauge.getReward();

    //     // console.log(bal.balanceOf(address(this)));
    //     // console.log(aura.balanceOf(address(this)));

    //     // IBalancer.SingleSwap memory singleSwap = IBalancer.SingleSwap({
    //     //     poolId: 0xcfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274,
    //     //     kind: IBalancer.SwapKind.GIVEN_IN,
    //     //     assetIn: address(aura),
    //     //     assetOut: address(weth),
    //     //     amount: aura.balanceOf(address(this)),
    //     //     userData: ""
    //     // });
    //     // IBalancer.FundManagement memory funds = IBalancer.FundManagement({
    //     //     sender: address(this),
    //     //     fromInternalBalance: false,
    //     //     recipient: address(this),
    //     //     toInternalBalance: false
    //     // });
    //     // uint amountOut = balancer.swap(singleSwap, funds, 0, block.timestamp);
    //     // console.log(aura.balanceOf(address(this)));
    //     // console.log(weth.balanceOf(address(this)));
    //     // console.log(amountOut);

    //     // address[] memory assets = new address[](2);
    //     // assets[0] = address(bal);
    //     // assets[1] = address(weth);
    //     // uint[] memory maxAmountsIn = new uint[](2);
    //     // maxAmountsIn[0] = bal.balanceOf(address(this));
    //     // IBalancer.JoinPoolRequest memory request = IBalancer.JoinPoolRequest({
    //     //     assets: assets,
    //     //     maxAmountsIn: maxAmountsIn,
    //     //     userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
    //     //     fromInternalBalance: false
    //     // });
    //     // balancer.joinPool(
    //     //     0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
    //     //     address(this),
    //     //     address(this),
    //     //     request
    //     // );
    //     // console.log(bal.balanceOf(address(this)));

    //     IBalancer.BatchSwapStep[] memory swaps = new IBalancer.BatchSwapStep[](2);
    //     swaps[0] = IBalancer.BatchSwapStep({
    //         poolId: 0xcfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274,
    //         assetInIndex: 0,
    //         assetOutIndex: 1,
    //         amount: aura.balanceOf(address(this)),
    //         userData: ""
    //     });
    //     swaps[1] = IBalancer.BatchSwapStep({
    //         poolId: 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
    //         assetInIndex: 1,
    //         assetOutIndex: 2,
    //         amount: 0,
    //         userData: ""
    //     });
    //     address[] memory assets = new address[](3);
    //     assets[0] = address(aura);
    //     assets[1] = address(weth);
    //     assets[2] = address(bal);
    //     IBalancer.FundManagement memory funds = IBalancer.FundManagement({
    //         sender: address(this),
    //         fromInternalBalance: false,
    //         recipient: address(this),
    //         toInternalBalance: false
    //     });
    //     int[] memory limits = new int[](3);
    //     limits[0] = int(aura.balanceOf(address(this)));
    //     balancer.batchSwap(
    //         IBalancer.SwapKind.GIVEN_IN,
    //         swaps,
    //         assets,
    //         funds,
    //         limits,
    //         block.timestamp
    //     );
    //     // console.log(bal.balanceOf(address(this)));
    //     // console.log(aura.balanceOf(address(this)));

    //     assets = new address[](2);
    //     assets[0] = address(bal);
    //     assets[1] = address(weth);
    //     uint[] memory maxAmountsIn = new uint[](2);
    //     maxAmountsIn[0] = bal.balanceOf(address(this));
    //     IBalancer.JoinPoolRequest memory request = IBalancer.JoinPoolRequest({
    //         assets: assets,
    //         maxAmountsIn: maxAmountsIn,
    //         userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
    //         fromInternalBalance: false
    //     });
    //     balancer.joinPool(
    //         0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
    //         address(this),
    //         address(this),
    //         request
    //     );
    //     // console.log(balWeth.balanceOf(address(this)));

    //     assets[0] = address(balWeth);
    //     assets[1] = address(auraBAL);
    //     maxAmountsIn = new uint[](2);
    //     maxAmountsIn[0] = balWeth.balanceOf(address(this));
    //     IAuraZap.JoinPoolRequest memory zapRequest = IAuraZap.JoinPoolRequest({
    //         assets: assets,
    //         maxAmountsIn: maxAmountsIn,
    //         userData: abi.encode(IBalancer.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0),
    //         fromInternalBalance: false
    //     });
    //     zap.depositSingle(
    //         address(gauge),
    //         address(balWeth),
    //         balWeth.balanceOf(address(this)),
    //         0x3dd0843a028c86e0b760b1a76929d1c5ef93a2dd000200000000000000000249,
    //         zapRequest
    //     );
    //     // console.log(balWeth.balanceOf(address(this)));
    //     // console.log(gauge.balanceOf(address(this)));
    // }

    function testCompound() public {
        uint amount = 10_000 ether;
        deal(address(lpToken), address(vault), amount);
        vault.deposit();
        // console.log(gauge.balanceOf(address(this)));

        skip(864000);
        vault.harvest();
    }
}

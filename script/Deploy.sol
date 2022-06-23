// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "src/PbCrvArbTri.sol";
import "src/PbCrvArb2p.sol";
import "src/PbCrvPolyTri.sol";
import "src/PbProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {

    address treasuryAddr = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E; // Change this

    // Arbitrum
    address WBTCAddr = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address WETHAddr = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDTAddr = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // // Polygon
    // address WBTCAddr = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    // address WETHAddr = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    // address USDCAddr = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    
    function run() public {
        vm.startBroadcast();

        // Arbitrum tricrypto BTC/ETH/USDT
        // PbCrvArbTri pbCrvArbTriImpl = new PbCrvArbTri();
        address pbCrvArbTriImpl = 0x51d0bbC9B2bcB8a7bfA6B74aB9Fb8E23cFc66757;

        // PbProxy pbCrvArbTriProxy_WBTC = new PbProxy(
        //     address(pbCrvArbTriImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         WBTCAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArbTriProxy_WBTC:", address(pbCrvArbTriProxy_WBTC));

        PbProxy pbCrvArbTriProxy_WETH = new PbProxy(
            address(pbCrvArbTriImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,address)")),
                WETHAddr,
                treasuryAddr
            )
        );
        console.log("pbCrvArbTriProxy_WETH:", address(pbCrvArbTriProxy_WETH));

        // PbProxy pbCrvArbTriProxy_USDT = new PbProxy(
        //     address(pbCrvArbTriImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         USDTAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArbTriProxy_USDT:", address(pbCrvArbTriProxy_USDT));



        // // Arbitrum 2pool BTC/ETH
        // PbCrvArb2p pbCrvArb2pImpl = new PbCrvArb2p();

        // PbProxy pbCrvArb2pProxy_WBTC = new PbProxy(
        //     address(pbCrvArb2pImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         WBTCAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArb2pProxy_WBTC:", address(pbCrvArb2pProxy_WBTC));

        // PbProxy pbCrvArb2pProxy_WETH = new PbProxy(
        //     address(pbCrvArb2pImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         WETHAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArb2pProxy_WETH:", address(pbCrvArb2pProxy_WETH));



        // Polygon tricrypto BTC/ETH/USDC
        // PbCrvArbTri pbCrvArbTriImpl = new PbCrvArbTri();

        // PbProxy pbCrvArbTriProxy_WBTC = new PbProxy(
        //     address(pbCrvArbTriImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         WBTCAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArbTriProxy_WBTC:", address(pbCrvArbTriProxy_WBTC));

        // PbProxy pbCrvArbTriProxy_WETH = new PbProxy(
        //     address(pbCrvArbTriImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         WETHAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArbTriProxy_WETH:", address(pbCrvArbTriProxy_WETH));

        // PbProxy pbCrvArbTriProxy_USDC = new PbProxy(
        //     address(pbCrvArbTriImpl),
        //     abi.encodeWithSelector(
        //         bytes4(keccak256("initialize(address,address)")),
        //         USDCAddr,
        //         treasuryAddr
        //     )
        // );
        // console.log("pbCrvArbTriProxy_USDC:", address(pbCrvArbTriProxy_USDC));
    }
}

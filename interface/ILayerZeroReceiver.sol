// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for contract that receive payload from layer zero endpoint
interface ILayerZeroReceiver {
    // @notice LayerZero endpoint will invoke this function to deliver the message on the destination
    // @param srcChainId_ - the source endpoint identifier
    // @param srcAddress_ - the source sending contract address from the source chain
    // @param nonce_ - the ordered message nonce
    // @param payload_ - the signed payload is the UA bytes has encoded to be sent
    function lzReceive(
        uint16 srcChainId_,
        bytes calldata srcAddress_,
        uint64 nonce_,
        bytes calldata payload_
    ) external;
}
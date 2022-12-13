// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for sudoswap pool
interface ISudoPool {
    function getBuyNFTQuote(uint) external view returns (
        uint8 error,
        uint newSpotPrice,
        uint newDelta,
        uint inputAmount,
        uint protocolFee
    );
}
# PengTogether

## Contract integration

User only interact with Vault contract.

This contract only accept USDC (0x7F5c764cBc14f9669B88837ca1490cCa17c31607).

Useful function for UI on vault contract on Optimism: `deposit`, `withdraw`, `getAllPoolInUSD`, `getUserBalanceInUSD`.

Useful function for UI on record contract on Optimism: `getUserTotalTickets`, `getTotalSeats`.

No useful function for UI on contract on Ethereum.

`getUserBalanceInUSD(userAddr)` provider actual user balance in USD which show on UI.

`getUserDepositBalance(userAddr)` is user actual deposit balance without slippage. This amount will be slightly higher than amount get from `getUserBalanceInUSD(userAddr)`. This can be used as the maximum amount user can withdraw.

`amount` in withdraw function is the actual amount user want to withdraw. Amount user receive eventually will be slightly less than input amount due to slippage.

## Contract addresses - Vaults

### sUSD-3CRV farm

Vault: 0x68ca3a3BBD306293e693871E45Fe908C04387614 (Optimism)

Record: 0x176B6aD5063bFFBca9867DE6B3a1Eb27A306e40d (Optimism)

Reward: 0xF7A1f8918301D9C09105812eB045AA168aB3BFea (Ethereum)

Dao: 0x28BCc4202cd179499bF618DBfd1bFE37278E1A12 (Ethereum)

### sETH-ETH farm

Vault: 0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250 (Optimism)

Record: 0xC530677144A7EA5BaE6Fbab0770358522b4e7071 (Optimism)

Reward: 0xB7957FE76c2fEAe66B57CF3191aFD26d99EC5599 (Ethereum)

Dao: 0x0C9133Fa96d72C2030D63B6B35c3738D6329A313 (Ethereum)

## Contract addresses - Helpers

Ethereum: 0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab

Optimism: 0xCf91CDBB4691a4b912928A00f809f356c0ef30D6

## Lucky Draw Progress

1. Admin call `placeSeat(users)` on Record contract

2. Check `totalSeats` on Dao Ethereum contract is same as `seats(getSeatsLength() - 1).to + 1`

3. Anyone can set random seat by call `requestRandomWords` on Dao Ethereum contract

4. Get random seat via `randomSeat` on Dao Ethereum contract

5. Get seat owner (`winner`) via `getSeatOwner(randomSeat)` on Record Optimism contract

6. Admin call `setWinnerAndRestartRound(winner)` on Record Optimism contract

7. Check `winner` on Dao Ethereum contract is correct

8. Search `pool` by go `sudoswap.xyz` -> Search collection -> Pools -> copy Floor Price and paste at Max Price (ETH) -> search for pool with Balance: amount NFT -> click address above Owner -> click copy icon beside address below NFT <-> ETH

9. Admin call `buyNFT(pool)` on Reward Ethereum contract

10. Anyone can call `distributeNFT()` to distribute NFT to winner on Dao Ethereum contract
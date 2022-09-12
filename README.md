# PengTogether

## Contract integration

User only interact with Vault contract.

This contract only accept USDC (0x7F5c764cBc14f9669B88837ca1490cCa17c31607).

`getUserBalanceInUSD(userAddr)` provider actual user balance in USD which show on UI.

`getUserDepositBalance(userAddr)` is user actual deposit balance without slippage. This amount will be slightly higher than amount get from `getUserBalanceInUSD(userAddr)`. This can be used as the maximum amount user can withdraw.

`amount` in withdraw function is the actual amount user want to withdraw. Amount user receive eventually will be slightly less than input amount due to slippage.

## Contract addresses

Vault: 0x8EdF0c0f9C56B11A5bE56CB816A2e57c110f44b1 (Optimism)

Farm: 0xB68F3D8E341B88df22a73034DbDE3c888f4bE9DE (Optimism)

Reward: (Ethereum)

## Lucky Draw Progress

1. Call `placeSeat(users)` on PengTogether Optimism contract

2. Check `totalSeats` on Reward Ethereum contract is correct

3. Request random seat by call `requestRandomWords()` on Reward Ethereum contract

4. Get random seat via `randomSeat` on Reward Ethereum contract

5. Get seat owner via `getSeatOwner(randomSeat)` with `randomSeat` above on PengTogether Optimism contract

6. Call `setWinnerAndRestartRound(winner)` with `winner` above on PengTogether Optimism contract

7. Check `winner` on Reward Ethereum contract is correct

8. Search pool by go `sudoswap.xyz` -> Search collection -> Pools -> copy Floor Price and paste at Max Price (ETH) -> search for pool with Balance: amount NFT -> click address above Owner -> click copy icon beside address below NFT <-> ETH

9. Call `buyNFTAndRewardWinner(pool)` with `pool` above on Reward Ethereum contract

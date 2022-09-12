# PengTogether

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

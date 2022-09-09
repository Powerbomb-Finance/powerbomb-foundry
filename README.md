# Powerbomb Uniswap V3

## Notes

`rewardToken` needed for `deposit()` & `withdraw()` is the reward token that user choose, either WBTC or WETH.

WBTC address: 0x68f180fcCe6836688e9084f035309E29Bf0A2095

WETH address: 0x4200000000000000000000000000000000000006

`claimReward()` claim both wbtc & weth reward

`getUserBalance(userAddr)` = getUserBalanceInUSD, there is no getUserBalanceInUSD in this vault

`getUserPendingReward(userAddr, rewardToken)` rewardToken either WBTC or WETH

## Addresses

### Optimism

vault: 0xAb736E1D68f3A51933E0De23CbC6c1147d0C2934 (user interact with this contract only)

reward: 0xf4c8dd2BB19B9898d65881D88660F8AEBb03064D

## Summary

The strategy utilize Uniswap V3 on Arbitrum and Optimism. Users deposit USDC into strategy with pre-fixed range. Strategy change price range from time to time based on current market price, try to get better trading fees. The fees then turn into tokens that chosen by users (WBTC & WETH on launch). Users able to exit from strategy by withdraw out in form of USDC.

<br>

## Contracts & Main Functions

<br>

### PbUniV3.sol

<br>

> deposit(amount, amountsOutMin, slippage, tickLower, tickUpper, rewardToken)

**Info**

Users deposit USDC into strategy. `harvest()` will execute first to prevent yield sandwich attack. USDC then swap into pair needed tokens. These tokens then calculate slippage and add liquidity into pair. First ever deposit will mint Uniswap V3 position in NFT. Amount deposit and chosen farm reward will record into reward contract.

**Parameters**

`amount`: amount of USDC to deposit

`amountsOutMin`: slippage check for swap

`slippage`: slippage check for add liquidity into pair

`tickLower` & `tickUpper`: price range, only applicable for first deposit (mint Uniswap V3 NFT), else 0

`rewardToken`: tokens user choose as farm reward

<br>

> reinvest(tokenIn, amount, amountOutMin, slippage)

**Info**

This function is to add back tokens that left by last liquidity adding. It normally execute after user deposit. In nature Uniswap V3 return un-utilize tokens back to strategy. The bot will check returned tokens, and execute this function if value > certain threshold. This function can only be called by authorized account.

**Parameters**

`tokenIn`: token that return the most from Uniswap V3

`amount`: amount of token above

`amountOutMin`: amountsOutMin for swap half to other token within pair

`slippage`: slippage for add liquidity into pair

<br>

> withdraw(amount, rewardToken, amount0Min, amount1Min, amountsOutMin)

**Info**

Withdraw USDC from strategy. Strategy first calculate out liquidity to remove from pair, swap any non-USDC token to USDC and transfer to user.

**Parameters**

`amount`: amount of USDC to withdraw

`rewardToken`: chosen token as farm reward

`amount0Min` & `amount1Min`: slippage check for remove liquidity from pair

`amountsOutMin`: slippage check for swap

<br>

> harvest()

**Info**

This function collect fees from Uniswap V3 and send to reward contract and turn into users chosen farm reward. This function called alongside with `deposit()` (to prevent yield sandwich attack), `claimReward()` (to provide user updated reward), and `updateTicks()` (to harvest any unclaimed fees before move liquidity).

**Parameters**

\-

<br>

> claimReward()

**Info**

This function trigger `claim()` of reward contract. `harvest()` will execute first to provide user updated reward.

**Parameters**

\-

<br>

> updateTicks(tickLower, tickUpper, amount0Min, amount1Min, slippage)

**Info**

This function remove liquidity from Uniswap V3 position, burn minted position NFT, calculate slippage for add liquidity and mint new position NFT with given ticks. This function is executed when we need to adjust price range, especially when market price has major move, either up or down. `harvest()` will execute first to harvest any unclaimed fees before move liquidity. This function can be called by authorized only.

**Parameters**

`tickLower` & `tickUpper`: new price range

`amount0Min` & `amount1Min`: slippage check for remove liquidity from pair

`slippage`: slippage for add liquidity into pair

<br>

> setReward(newRewardAddr)

**Info**

This function change reward contract that this contract interate with. This function only able to call by owner of this contract. Emit `SetReward` event upon change.

**Parameters**

`newRewardAddr` : new reward contract address

<br>

> setBot(newBotAddr)

**Info**

This function change bot wallat that able to call `reinvest` and `updateTicks` function. This function only able to call by owner of this contract. Emit `SetBot` event upon change.

**Parameters**

`newBotAddr` : new Bot wallet address

<br>
<br>

### PbUniV3Reward.sol

<br>

> recordDeposit(account, amount, rewardToken)

**Info**

This function can be called by vault contract only, alongside with `deposit()` from vault contract. It record user deposit amount, chosen token as farm reward and a checkpoint variable to determine user portion of reward. It also record current TVL in each type of farm reward.

**Parameters**

`account`: user wallet address to deposit

`amount`: user deposit amount

`rewardToken`: user chosen token as farm reward

<br>

> recordWithdraw(account, amount, rewardToken)

**Info**

This function can be called by vault contract only, alongside with `withdraw()` from vault contract. It record user withdraw amount, chosen token as farm reward and a checkpoint variable to determine user portion of reward. It also record current TVL in each type of farm reward.

**Parameters**

`account`: user wallet address to withdraw

`amount`: user withdraw amount

`rewardToken`: user chosen token as farm reward

<br>

> harvest(amount0, amount1)

**Info**

This function can be called by vault contract only, alongside with `harvest()` from vault contract. It transfer fee token(s) from vault contract, and calculate token(s) amount distributed for each farm reward (token). For each distributed token(s), it turn into farm reward token, collect treasury fee and lastly supply into Aave for interest bearing aToken. Before each harvest, contract update amount of aToken associate checkpoint reward variable.

**Parameters**

`amount0` & `amount1`: amount of tokens that transfer from vault contract as fees.

<br>

> claim(account)

**Info**

This function can be called by vault contract only, alongside with `claimReward()` from vault contract. It calculate user portion of reward token(s), update user record and latest aToken balance after withdraw. Contract then withdraw user chosen token from Aave, and transfer to user.

**Parameters**

`account`: user wallet address who claim

<br>

> setVault(newVaultAddr)

**Info**

This function change vault contract that retrieve tokens from and able to call `recordDeposit`, `recordWithdraw`, `harvest` and `claim` function. This function only able to call by owner of this contract. Emit `SetVault` event upon change.

**Parameters**

`newVaultAddr` : new Vault contract address

<br>

> setTreasury(newTreasuryAddr)

**Info**

This function change treasury wallet that receive fees from this contract. This function only able to call by owner of this contract. Emit `SetTreasury` event upon change.

**Parameters**

`newTreasuryAddr` : new treasury wallet address

<br>
<br>

### PbProxy.sol

Proxy contract to store state variables for PbUniV3 and PbUniV3Reward.

<br>
<br>

## Test

Install Foundry

https://book.getfoundry.sh/getting-started/installation.html

```
git clone https://github.com/Powerbomb-Finance/powerbomb-foundry
cd powerbomb-foundry
git switch univ3
forge install
```

Run test

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> --fork-block-number 13069100
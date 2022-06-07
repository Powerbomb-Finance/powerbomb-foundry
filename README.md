# Powerbomb Uniswap V3 Arbitrum

## Summary

The strategy utilize Uniswap V3 on Arbitrum. Users deposit USDC into strategy with pre-fixed range. Strategy change price range from time to time based on current market price, to get the most trading fees. The fees then swap into tokens that chosen by users (WETH & USDC on launch). Users able to exit from strategy by withdraw out in form of USDC.

## Contracts & Main Functions

### PbUniV3.sol

> deposit(amount, amountsOutMin, slippage, tickLower, tickUpper, rewardToken)

**Info**

Users deposit USDC into strategy. `harvest()` will execute first to prevent yield sandwich attack. USDC then swap into needed tokens. These tokens then calculate slippage and add liquidity into pair. First ever deposit will mint Uniswap V3 position in NFT. Amount deposit & chosen token as reward will record into reward contract.

**Parameters**

`amount`: amount of USDC to deposit
`amountsOutMin`: slippage check for swap
`slippage`: slippage check for add liquidity into pair
`tickLower` & `tickUpper`: price range, only applicable for first deposit (mint Uniswap V3 NFT), else 0
`rewardToken`: tokens user choose as reward from farm

> reinvest(tokenIn, amount, amountOutMin, slippage)

**Info**

This function is to add back tokens that left by last liquidity adding. It normally execute after user deposit. Uniswap V3 return un-utilize tokens back to strategy, due to the nature of "concentrated liquidity". The bot will check returned tokens, and execute this function if value > $100. This function can be called by authorized only.

**Parameters**

`tokenIn`: token that return the most by Uniswap V3
`amount`: amount of token above
`amountOutMin`: amountsOutMin for swap half to other token
`slippage`: slippage for add liquidity into pair

> withdraw(amount, rewardToken, amount0Min, amount1Min, amountsOutMin)

**Info**

Withdraw USDC from strategy. Strategy first calculate out liquidity to remove from pair, swap any non-USDC token to USDC and transfer to user.

**Parameters**

`amount`: amount of USDC to withdraw (won't be exact same amount after withdrawal)
`rewardToken`: chosen token as reward from farm
`amount0Min` & `amount1Min`: slippage check for remove liquidity from pair
`amountsOutMin`: slippage check for swap

> harvest()

**Info**

This function collect fees from Uniswap V3 and send to reward contract and turn into users chosen reward token. This function called alongside with `deposit()` (to prevent yield sandwich attack), `claimReward()` (to provide user updated reward), and `updateTicks()` (to harvest any unclaimed fees before move liquidity).

**Parameters**

-

> claimReward()

**Info**

This function trigger `claim()` of reward contract. `harvest()` will execute first to provide user updated reward.

**Parameters**

-

> updateTicks(tickLower, tickUpper, amount0Min, amount1Min, slippage)

**Info**

This function remove liquidity from Uniswap V3 position, burn minted position NFT, calculate slippage for add liquidity and mint new position NFT with given ticks. This function is executed when we need to adjust price range, especially when market price has major move, either up or down. `harvest()` will execute first to harvest any unclaimed fees before move liquidity. This function can be called by authorized only.

**Parameters**

`tickLower` & `tickUpper`: new price range
`amount0Min` & `amount1Min`: slippage check for remove liquidity from pair
`slippage`: slippage for add liquidity into pair

### PbUniV3Reward.sol

> recordDeposit(account, amount, rewardToken)

**Info**

This function can be called by vault contract only, alongside with `deposit()` from vault contract. It record user deposit amount, chosen token as farm reward and a checkpoint variable to determine user portion of reward. It also record current TVL in each type of reward.

**Parameters**

`account`: user wallet address to deposit
`amount`: user deposit amount
`rewardToken`: user chosen token as farm reward

> recordWithdraw(account, amount, rewardToken)

**Info**

This function can be called by vault contract only, alongside with `withdraw()` from vault contract. It record user withdraw amount, chosen token as farm reward and a checkpoint variable to determine user portion of reward. It also record current TVL in each type of reward.

**Parameters**

`account`: user wallet address to withdraw
`amount`: user withdraw amount
`rewardToken`: user chosen token as farm reward

> harvest(amount0, amount1)

**Info**

This function can be called by vault contract only, alongside with `harvest()` from vault contract. It transfer fee token(s) from vault contract, and calculate token(s) amount distributed for each farm reward (token). For each distributed token(s), it turn into farm reward token, collect treasury fee and lastly supply into Aave for interest bearing aToken. Before each harvest, contract update amount of aToken associate checkpoint variable as reward.

**Parameters**

`amount0` & `amount1`: amount of tokens that transfer from vault contract as fees.

> claim(account)

**Info**

This function can be called by vault contract only, alongside with `claimReward()` from vault contract. It calculate user portion of reward token(s), update user record and latest aToken balance, withdraw from Aave, and transfer to user.

**Parameters**

`account`: user wallet address who claim

### PbUniV3Proxy.sol

Proxy contract to store state variables for PbUniV3 and PbUniV3Reward.

## Test

Install Foundry

https://book.getfoundry.sh/getting-started/installation.html

Run test

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> --fork-block-number 13069100
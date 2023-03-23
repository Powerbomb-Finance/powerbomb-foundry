# Powerbomb Velodrome (Optimism)

## USDC-sUSD vault

### Summary

Deposit/withdraw USDC/sUSD/LP token into vault. Rewards in WBTC/WETH.

### Contract

WBTC reward: 0x208e2D48b5A080E57792D8b175De914Ddb18F9a8

WETH reward: 0xee9857e5e1d0089075F75ABe5255fc30695d09FA

### Tokens

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

sUSD: 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9

LP token: 0xd16232ad60188B68076a235c65d692090caba155



## FRAX-USDC vault

### Summary

Deposit/withdraw FRAX/USDC/LP token into vault. Rewards in WBTC/WETH.

### Contract

WBTC reward: 0x74f6C748E2DF1c89bf7ed29617A2B41b0f4f82A2

WETH reward: 0x75633BFAbf0ee9036af06900b8f301Ed8ed29121

### Tokens

FRAX: 0x2E3D870790dC77A83DD1d18184Acc7439A53f475

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

LP token: 0xAdF902b11e4ad36B227B84d856B229258b0b0465



## USDC-DAI vault

### Summary

Deposit/withdraw USDC/DAI/LP token into vault. Rewards in WBTC/WETH.

### Contract

WBTC reward: 0xc23CF2762094a4Dd8DC3D4AaAAfdB38704B0f484

WETH reward: 0xC15d58452E7CC62F213534dcD1999EDcc4C56E53

### Tokens

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

DAI: 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1

LP token: 0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353



## USDC-LUSD vault

### Summary

Deposit/withdraw USDC/LUSD/LP token into vault. Rewards in WBTC/WETH.

### Contract

WBTC reward: 0xcaCdE37C8Aef43304e9d7153e668eDb7126Ff755

WETH reward: 0xf12a8E2Fd857B134381c1B9F6027D4F0eE05295A

### Tokens

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

LUSD: 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819

LP token: 0x207AddB05C548F262219f6bFC6e11c02d0f7fDbe



## USDC-MAI vault

### Summary

Deposit/withdraw USDC/MAI/LP token into vault. Rewards in WBTC/WETH.

### Contract

WBTC reward: 0x52671440732589E3027517E22c49ABc04941CF2F

WETH reward: 0x3BD8d78d77dfA391c5F73c10aDeaAdD9a7f7198C

### Tokens

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

MAI: 0xdFA46478F9e5EA86d57387849598dbFB2e964b02

LP token: 0xd62C9D8a3D4fd98b27CaaEfE3571782a3aF0a737



## OP-USDC vault

### Summary

Deposit/withdraw OP/USDC/LP token into vault. Rewards in WBTC/WETH/USDC.

### Contract

WBTC reward: 0x2510E5054eeEbED40C3C580ae3241F5457b630D9

WETH reward: 0xFAcB839BF8f09f2e7B4b6C83349B5bbFD62fd659

USDC reward: 0x176CC5Ff9BDBf4daFB955003E6f8229f47Ef1E55

### Tokens

OP: 0x4200000000000000000000000000000000000042

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

LP token: 0x47029bc8f5CBe3b464004E87eF9c9419a48018cd



## WETH-USDC vault

### Summary

Deposit/withdraw native ETH/USDC/LP token into vault. Rewards in WBTC/WETH/USDC.

### Contract

WBTC reward: 0xa0Ea9A553cB47658e62Dee4D7b49F7c8Da234B69

WETH reward: 0xd0f9990a611018b5b30BFE1C5433bf5bba2a9868

USDC reward: 0x0F0fFF5EA56b0eA2246A926F13181e33Be9FbAEA

### Tokens

WETH: 0x4200000000000000000000000000000000000006 (deposit in native ETH)

USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607

LP token: 0x79c912FEF520be002c2B6e57EC4324e260f38E50



## WETH-sETH vault

### Summary

Deposit/withdraw native ETH/sETH/LP token into vault. Rewards in USDC.

### Contract

USDC reward: 0xcba7864134e1A5326b817676ad5302A009c84d68

WBTC reward: 0x3eB3D7d12a6421fb4D261D62431b34382fc2f72D

WETH reward: 0x225169A63864f9E6d1B92bdB43118D701fAF7531

### Tokens

WETH: 0x4200000000000000000000000000000000000006 (deposit in native ETH)

sETH: 0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49

LP token: 0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F


## Checklist for deploy/upgrade contract

### before

1. forge test

2. slither

3. forge coverage

4. solhint

### after

1. forge test without upgrade code

## Slither

Make sure to have `slither.config.json` in root folder, then just run the command below.

> slither src/{contract_name}.sol

## Coverage

Install VSCode extension "Coverage Gutters". Run command below. Go to contract page and click "Watch" at the very bottom.

> forge coverage -f {rpc_url} --match-contract {contract_name} --report lcov

## Solhit

Make sure to have `solhint.json` in root folder, then just run the command below.

> solhint src/{contract_name}.sol
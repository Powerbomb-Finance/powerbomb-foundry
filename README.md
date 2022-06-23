# Powerbomb

## Vault addresses

### Arbitrum

#### atricrypto

WBTC: 0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5

WETH: 0xb88c7a8e678b243a6851b9fa82a1aa0986574631

USDT: 0x8ae32c034dacd85a79cfd135050fcb8e6d4207d8

#### 2pool

WBTC: 0xe616e7e282709d8b05821a033b43a358a6ea8408

WETH: 0xbe6a4db3480efccab2281f30fe97b897beef408c

### Polygon

#### atricrypto

WBTC: 0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab

WETH: 0x5abbEB3323D4B19C4C371C9B056390239FC0Bf43

USDC: 0x7331f946809406F455623d0e69612151655e8261

## Test

### Arbitrum

#### tricrypto

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15370000 -vvv --match-contract PbCrvArbTriTest

#### 2pool

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15370000 -vvv --match-contract PbCrvArb2pTest

### Polygon

#### tricrypto

> forge test --fork-url https://polygon-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 29875300 -vvv --match-contract PbCrvPolyTriTest

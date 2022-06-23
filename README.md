# Powerbomb

## Vault addresses

### Arbitrum

#### atricrypto

WBTC: 0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5

WETH: 0xb88C7a8e678B243a6851b9Fa82a1aA0986574631

USDT: 0x8Ae32c034dAcd85a79CFd135050FCb8e6D4207D8

#### 2pool

WBTC: 0xE616e7e282709d8B05821a033B43a358a6ea8408

WETH: 0xBE6A4db3480EFccAb2281F30fe97b897BeEf408c

### Polygon

#### atricrypto

WBTC: 0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab

WETH: 0x5abbEB3323D4B19C4C371C9B056390239FC0Bf43

USDC: 0x7331f946809406F455623d0e69612151655e8261

## Test

### Arbitrum

#### tricrypto

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15533265 -vvv --match-contract PbCrvArbTriTest

#### 2pool

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15533265 -vvv --match-contract PbCrvArb2pTest

### Polygon

#### tricrypto

> forge test --fork-url https://polygon-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 29914756 -vvv --match-contract PbCrvPolyTriTest

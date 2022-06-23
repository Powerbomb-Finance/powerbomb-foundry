# Powerbomb

## Vault addresses

### Arbitrum

#### atricrypto

WBTC: 0x5bA0139444AD6f28cC28d88c719Ae85c81C307a5

WETH: 

USDT: 

#### 2pool

WBTC: 

WETH: 

### Polygon

#### atricrypto

WBTC: 

WETH: 

USDC: 

## Test

### Arbitrum

#### tricrypto

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15370000 -vvv --match-contract PbCrvArbTriTest

#### 2pool

> forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 15370000 -vvv --match-contract PbCrvArb2pTest

### Polygon

#### tricrypto

> forge test --fork-url https://polygon-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY> --fork-block-number 29875300 -vvv --match-contract PbCrvPolyTriTest

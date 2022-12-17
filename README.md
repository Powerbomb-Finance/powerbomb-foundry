# PengTogether

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

## Checklist for upgrade contract

### before

1. forge test

2. slither

3. forge coverage

### after

1. forge test without upgrade code

## Slither

> slither src/contract.sol

## Coverage

PengHelperEth.sol

> forge coverage -f https://rpc.ankr.com/eth --match-contract PengHelperEthTest --report lcov

PengHelperOp.sol

> forge coverage -f https://rpc.ankr.com/optimism --match-contract PengHelperOpTest --report lcov

PengTogether.sol & Record.sol

> forge coverage -f https://rpc.ankr.com/optimism --match-contract PengTogetherTest --report lcov

Vault_seth.sol & Record_eth.sol

> forge coverage -f https://rpc.ankr.com/optimism --match-contract Vault_sethTest --report lcov

Reward.sol & Dao.sol

> forge coverage -f https://rpc.ankr.com/optimism --match-contract RewardTest --report lcov
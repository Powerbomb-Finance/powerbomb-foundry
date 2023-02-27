# Aura

## wstETH/WETH

Deposit/withdraw wstETH, native ETH (pass in as WETH), LP token

Reward in USDC only

vault: 0x3bBc9Dc447D12a2ea196a3395dd6bCb06fF07631

## Slither

Just run the command below.

> slither src/<contract name>.sol

## Coverage

Install VSCode extension "Coverage Gutters". Run command below. Go to contract page and click "Watch" at the very bottom.

> forge coverage -f https://rpc.ankr.com/eth --match-contract <contract name> --report lcov
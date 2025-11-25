# Yield Vault Contract

A smart contract where users can deposit tokens and automatically earn
on-chain yield over time based on vault performance.

## Key Functions
- `deposit` — Add tokens into the yield vault
- `withdraw` — Redeem stored funds and earned rewards
- `calculate-reward` — Determine accumulated yield per user
- `update-rate` — Adjust APY or strategy metrics (authorized only)
- `get-balance` — View user deposit + reward total

Ideal for earning passive yield from staking, lending strategies, or DAO-backed
reward engines.

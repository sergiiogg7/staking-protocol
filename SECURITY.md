# Security

## Status

This repository has not been externally audited. Security measures are listed below and verified by CI.

## Measures

| Measure | Location |
|---|---|
| Strict CEI ordering | `StakingApp.depositToken`, `StakingApp.withdrawTokens` |
| Reentrancy guard on all state-changing user functions | `StakingApp` (`nonReentrant`) |
| Two-step ownership transfer | `StakingApp` (`Ownable2Step`) |
| Exit path never paused | `StakingApp.withdrawTokens` |
| Zero-address, zero-amount and period-bounds validation | `StakingApp` constructor, `changeStakingPeriod` |
| Safe ERC20 transfers | `StakingApp` (`SafeERC20`) |
| Custom errors only, no `require` strings | all contracts in `src/` |
| Static analysis | Slither in CI (`slither.config.json`) |
| Fuzz and invariant testing | `test/StakingAppFuzz.t.sol`, `test/StakingAppInvariant.t.sol` |

## Invariants

- `totalPositions * fixStakingAmount == stakingToken.balanceOf(StakingApp)`
- `StakingApp.balance == ETH funded - ETH claimed`
- `userTokenId[user]` and NFT ownership never diverge.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository. Do not open a public issue.

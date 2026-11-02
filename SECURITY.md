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
- Every open position is a live NFT with `lastActivity[tokenId] != 0`, and the number of open positions equals `totalPositions`.

## Design notes

- **Positions are bearer instruments.** `claimRewards` and `withdrawTokens` authorize with `StakingNFT.ownerOf(tokenId)`. Whoever owns the NFT controls the position, including accrued staking time.
- **Approved operators cannot act.** An address approved through `approve` or `setApprovalForAll` can transfer the NFT but cannot claim or withdraw on its behalf.
- **Losing the NFT means losing the position.** A phished `setApprovalForAll` signature lets an attacker transfer the NFT and then withdraw the staked tokens.
- **Selling a position with pending rewards.** The buyer collects the reward; the seller can claim just before selling. The price of a position should account for this.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository. Do not open a public issue.

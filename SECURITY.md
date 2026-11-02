# Security

## Status

This repository has not been externally audited. Security measures are listed below and verified by CI.

## Measures

| Measure | Location |
|---|---|
| Strict CEI ordering | `StakingApp.depositToken`, `StakingApp.withdrawTokens` |
| Reentrancy guard on all state-changing user functions | `StakingApp` (`nonReentrant`) |
| Two-step ownership transfer | `StakingApp`, `StakingToken`, `StakingNFT` (`Ownable2Step`) |
| Exit path never paused | `StakingApp.withdrawTokens` |
| Zero-address, zero-amount and period-bounds validation | `StakingApp` constructor |
| Safe ERC20 transfers | `StakingApp` (`SafeERC20`) |
| Custom errors only, no `require` strings | all contracts in `src/` |
| Static analysis | Slither in CI (`slither.config.json`) |
| Fuzz and invariant testing | `test/StakingAppFuzz.t.sol`, `test/StakingAppInvariant.t.sol` |

## Invariants

- `totalPositions * fixStakingAmount == stakingToken.balanceOf(StakingApp)`
- `StakingApp.balance == ETH funded - ETH claimed - ETH withdrawn by the owner`
- The owner never withdraws ETH while a position is open.
- Every open position is a live NFT with `lastActivity[tokenId] != 0`, and the number of open positions equals `totalPositions`.

## Design notes

- **Positions are bearer instruments.** `claimRewards` and `withdrawTokens` authorize with `StakingNFT.ownerOf(tokenId)`. Whoever owns the NFT controls the position, including accrued staking time.
- **Approved operators cannot act.** An address approved through `approve` or `setApprovalForAll` can transfer the NFT but cannot claim or withdraw on its behalf.
- **Losing the NFT means losing the position.** A phished `setApprovalForAll` signature lets an attacker transfer the NFT and then withdraw the staked tokens.
- **Rewards are a liability that grows with time.** Every position accrues `rewardPerPeriod` per completed period whether or not it is claimed, and the contract does not reserve ETH for it. If the balance is lower than the amount owed, `claimRewards` reverts with `EthTransferFailed` until the owner funds the contract. The owner is responsible for keeping the balance above `sum(claimableRewards)`.
- **The owner can recover ETH only when no position is open.** `withdrawEther` reverts with `PositionsStillOpen` while `totalPositions > 0`, so it can never reduce what a staker is able to collect. The cost is that surplus ETH cannot be taken out mid-life, and a single open position blocks recovery. To wind the protocol down: stop funding, let stakers claim and withdraw, then call `withdrawEther`. Pausing is not a wind-down tool, because it blocks `claimRewards`.
- **Three independent owners.** `StakingApp`, `StakingToken` (can mint up to the cap) and `StakingNFT` (can replace the metadata descriptor) each have their own owner. Transferring one does not move the others, and each transfer needs the new owner to call `acceptOwnership`. `renounceOwnership` remains available on all three and is irreversible.
- **Economic parameters are immutable.** `stakingPeriod`, `fixStakingAmount` and `rewardPerPeriod` are fixed at deployment, so the owner cannot change what open positions have accrued. Changing them requires deploying a new `StakingApp`; positions in the old one keep working until withdrawn.
- **Selling a position with pending rewards.** The buyer collects the reward; the seller can claim just before selling. The price of a position should account for this.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository. Do not open a public issue.

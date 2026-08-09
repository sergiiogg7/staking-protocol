# Staking Protocol

A fixed-amount staking protocol on Ethereum, written in Solidity and tested with Foundry. Users deposit a fixed amount of a staking token, lock it for a configurable period, and claim ETH rewards. The protocol is admin-managed through OpenZeppelin's `Ownable`.

![CI](https://github.com/sergiiogg7/FoundryFirstRepo/actions/workflows/test.yml/badge.svg)
![Solidity ^0.8.24](https://img.shields.io/badge/Solidity-%5E0.8.24-blue)
![Foundry](https://img.shields.io/badge/built%20with-Foundry-FF6B6B)
![Tests](https://img.shields.io/badge/tests-13%20passing-green)
![License: UNLICENSED](https://img.shields.io/badge/license-UNLICENSED-lightgrey)

---

## Overview

This project implements a complete staking flow with two contracts:

- **`StakingToken`** — a mintable `ERC20` token that acts as the staking asset.
- **`StakingApp`** — the staking contract where users deposit a fixed token amount and earn fixed ETH rewards per completed staking period.

The project demonstrates core smart-contract engineering skills: access control, the **CEI (Check-Effects-Interactions)** pattern, event logging, and a full Foundry test suite with time manipulation.

## How it works

1. **Owner** deploys `StakingToken` and `StakingApp`, setting the staking period, the fixed staking amount, and the ETH reward per period.
2. **Owner** funds the `StakingApp` contract with ETH by sending it directly (`receive()`).
3. **User** mints the required amount of `StakingToken` and calls `depositToken()` with the exact fixed amount (users can only stake once).
4. After the staking period elapses, **user** calls `claimRewards()` to receive the fixed ETH reward.
5. **User** can `withdrawTokens()` at any time after depositing to recover their tokens.
6. **Owner** can update the staking period via `changeStakingPeriod()`.

## Contracts

| Contract | Path | Purpose |
|---|---|---|
| `StakingApp` | [`src/StakingApp.sol`](src/StakingApp.sol) | Core staking logic: deposit, withdraw, claim rewards, admin functions |
| `StakingToken` | [`src/StakingToken.sol`](src/StakingToken.sol) | Mintable ERC20 token used as the staking asset |

### Key functions

| Function | Access | Description |
|---|---|---|
| `depositToken(uint256)` | anyone | Deposits the exact fixed amount of the staking token (once per user) |
| `withdrawTokens()` | anyone | Withdraws the staked tokens (CEI pattern) |
| `claimRewards()` | anyone | Claims the fixed ETH reward after the staking period elapses |
| `changeStakingPeriod(uint256)` | owner only | Updates the required staking period |
| `receive()` | owner only | Funds the contract with ETH to pay out rewards |

## Security considerations

- **CEI (Check-Effects-Interactions)** pattern applied in `withdrawTokens()` to prevent reentrancy.
- **Access control** via OpenZeppelin `Ownable` for admin functions.
- **Fixed-amount invariant** enforced with `require` guards — a user can only stake the exact configured amount, once.
- **Reward claims** are gated by the staking period and revert safely if the contract has no ETH to send.

## Tech stack

- **Language:** Solidity `^0.8.24`
- **Framework:** Foundry (Forge, Anvil, Cast)
- **Libraries:** OpenZeppelin Contracts (ERC20, Ownable)
- **Testing:** Foundry tests with `vm.prank`, `vm.warp`, `vm.deal`, and revert assertions

## Getting started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) installed

```shell
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install dependencies

```shell
git clone --recurse-submodules https://github.com/sergiiogg7/FoundryFirstRepo.git
cd FoundryFirstRepo
```

### Build

```shell
forge build
```

### Run tests

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas snapshots

```shell
forge snapshot
```

### Local node

```shell
anvil
```

## Tests

13 tests across 2 suites, all passing. The suite covers:

- Deposit / withdraw flows and state transitions
- Reverts for wrong amounts, double deposits, and unauthorized access
- Reward claiming with time manipulation (`vm.warp`)
- ETH funding and insufficient-balance failure paths
- Owner-only access control

## Continuous integration

GitHub Actions runs `forge fmt --check`, `forge build --sizes`, and `forge test -vvv` on every push and pull request (see [`.github/workflows/test.yml`](.github/workflows/test.yml)).

## License

UNLICENSED

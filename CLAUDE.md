# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
forge build                          # Compile all contracts
forge test                           # Run all tests
forge test -vvv                      # Run tests with verbose output (shows traces)
forge test --match-test <name>       # Run a single test by name
forge test --match-contract <name>   # Run all tests in a specific contract
forge test --gas-report              # Run tests with gas usage report
forge snapshot --check               # Check for gas regressions vs. .gas-snapshot
forge fmt                            # Format Solidity files
forge fmt --check                    # Check formatting without modifying files
```

**Deploy locally (requires Anvil):**
```bash
cp .env.example .env   # fill in values
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Architecture

Two contracts with a clear separation of concerns:

- **`src/StakingToken.sol`** — mintable ERC20 (`ERC20` + `Ownable`). Hard cap of 1,000,000 STK. Only the owner can `mint` or batch-distribute via `distributeTokens`.

- **`src/StakingApp.sol`** — core staking logic (`Ownable2Step` + `ReentrancyGuard` + `Pausable`). Users deposit exactly `fixStakingAmount` tokens, wait `stakingPeriod` seconds, then call `claimRewards()` to receive `rewardPerPeriod` ETH. `withdrawTokens()` is always available even when paused. The three constructor params `stakingToken`, `fixStakingAmount`, and `rewardPerPeriod` are `immutable`; only `stakingPeriod` can be changed post-deploy via `changeStakingPeriod`.

The invariant: `StakingApp`'s token balance must always be ≥ the sum of all active `userBalance` values.

## Testing

Four test suites in `test/`:

| File | Type |
|---|---|
| `StakingAppTest.t.sol` | Unit — happy path, reverts, access control, pause |
| `StakingTokenTest.t.sol` | Unit — mint, distribute, access control |
| `StakingAppFuzz.t.sol` | Fuzz — deposit amounts, claim timing, period config |
| `StakingAppInvariant.t.sol` | Invariant — uses `StakingAppHandler` to constrain calls to valid state |

The invariant test uses a `StakingAppHandler` contract that wraps `StakingApp` calls. It pre-funds 5 staker addresses and tracks `totalDeposited` so the invariant can assert `tokenBalance >= totalDeposited`.

## CI Gates

CI runs on every push and blocks merges on:
- `forge fmt --check` — formatting
- `forge build` — compilation
- `forge test` — all tests passing
- `forge snapshot --check` — any gas regression vs `.gas-snapshot`
- Slither static analysis — any new finding in `src/` (dependencies excluded)

Update `.gas-snapshot` intentionally with `forge snapshot` when gas changes are expected.

## Git Conventions

- Do not add `Co-Authored-By` lines to commit messages.

## Security Patterns

- CEI (Check-Effects-Interactions) in `withdrawTokens` — `userBalance` is zeroed before the token transfer.
- All custom errors include parameters (`IncorrectAmount(expected, provided)`, `StakingPeriodNotElapsed(remaining)`) for debuggability.
- `receive()` is `onlyOwner` to prevent accidental ETH from third parties.
- Pause disables `depositToken` and `claimRewards` but never `withdrawTokens` — users can always exit.

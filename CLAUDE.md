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

### Contratos actuales
- **`src/StakingToken.sol`** — ERC20 mintable (`ERC20` + `Ownable`). Cap de 1,000,000 STK. Solo el owner puede `mint` o distribuir con `distributeTokens`.
- **`src/StakingApp.sol`** — lógica de staking (`Ownable2Step` + `ReentrancyGuard` + `Pausable`). Deposita exactamente `fixStakingAmount` tokens, espera `stakingPeriod` segundos y reclama `rewardPerPeriod` ETH. `withdrawTokens` siempre disponible aunque esté en pause. `stakingToken`, `fixStakingAmount` y `rewardPerPeriod` son `immutable`; solo `stakingPeriod` es mutable post-deploy.

### Evolución planificada (ver PLAN.md)
- **`src/StakingNFT.sol`** — ERC-721 en desarrollo. Cada posición de staking se representa como un NFT. Solo `StakingApp` puede mint/burn. `tokenURI` generado on-chain en base64.
- **`src/StakingApp.sol`** será refactorizado para usar `tokenId` en lugar de `userBalance` por address.
- Invariante nueva: `totalSupply(NFT) * fixStakingAmount == tokenBalance(StakingApp)`.

### Frontend (Fase 3)
Stack: Next.js 16 + wagmi v2 + viem v2 + RainbowKit v2 + Tailwind v4. Tres rutas: `/` (My Position), `/activity` (event log + Chainlink ETH/USD), `/admin` (owner panel). El frontend vive en `/frontend` dentro del mismo repo.

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

## Roadmap

El archivo `PLAN.md` en la raíz contiene las fases del proyecto con estado actualizado (🔲 pendiente · ⏳ en progreso · ✅ completado). Al completar cualquier tarea, actualizar el estado y añadir una fila al registro de cambios al final del archivo.

## Mentoría

Este proyecto tiene función de aprendizaje. Antes de implementar cualquier concepto nuevo (patrón, estándar, herramienta), explicar qué es, por qué se usa y qué problema resuelve. Razonar las decisiones de diseño. Al terminar cada fase, resumir qué habilidades se han añadido al perfil.

## Principios de ingeniería

- **Patrón AAA** en todos los tests: bloques `// Arrange`, `// Act`, `// Assert` explícitos y separados.
- **Nomenclatura de tests**: `test_<función>_<escenario>_<resultado esperado>`.
- **Custom errors con parámetros** en todos los reverts — nunca `require` con strings.
- **CEI estricto** en cualquier función que haga transferencias externas.
- **Sin magic numbers**: constantes siempre nombradas.
- **Events indexados** en todos los parámetros que se filtrarán off-chain.
- En frontend: hooks de contrato separados de componentes UI. ABIs importados con `as const`. Estado de transacción explícito en cada acción (idle → pending → confirming → success/error).

## Skills disponibles

- **`design-taste-frontend`** — genera UI con dirección artística real y verificación visual en navegador. Usar al inicio de la Fase 3. Instalar con: `/plugin marketplace add Leonxlnx/taste-skill`
- **`vercel-labs/skills`** (`find-skills`) — CLI para descubrir skills relevantes por palabra clave. Útil antes de iniciar el frontend para explorar el ecosistema. Instalar con: `npx skills add vercel-labs/agent-skills --skill find-skills -a claude-code`

## Git Conventions

- Do not add `Co-Authored-By` lines to commit messages.

## Security Patterns

- CEI (Check-Effects-Interactions) in `withdrawTokens` — `userBalance` is zeroed before the token transfer.
- All custom errors include parameters (`IncorrectAmount(expected, provided)`, `StakingPeriodNotElapsed(remaining)`) for debuggability.
- `receive()` is `onlyOwner` to prevent accidental ETH from third parties.
- Pause disables `depositToken` and `claimRewards` but never `withdrawTokens` — users can always exit.

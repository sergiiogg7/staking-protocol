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

### Contratos Fase 1 completados
- **`src/StakingNFT.sol`** — ERC-721 receipt. Cada posición de staking es un NFT. Solo `StakingApp` puede mint/burn (`onlyStakingApp`). `tokenURI` generado on-chain: SVG construido en Solidity → base64 → data URI, delegado a `StakingNFTDescriptor` (patrón renderer intercambiable, igual que Uniswap v3). Token IDs empiezan en 1; 0 es el sentinel "sin posición" en `StakingApp`.
- **`src/StakingApp.sol`** — refactorizado: `userBalance` → `userTokenId`, `elapsePeriod` → `lastActivity`. Invariante: `totalPositions * fixStakingAmount == tokenBalance(StakingApp)`.
- **`src/ITokenURIDescriptor.sol`** — interfaz del renderer. Declarada `view` (no `pure`) para que implementaciones futuras que lean feeds externos (Chainlink) sean compatibles sin cambiar la firma.
- **`src/StakingNFTDescriptor.sol`** — renderer concreto. SVG on-chain con los datos de la posición.

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
- **Sin comentarios de flujo inline**: no `// Checks`, `// Effects`, `// Interactions`, `// CEI:`. El código se entiende por sí solo; los comentarios son para el *por qué*, no para el *qué*.
- **Sin over-engineering**: no añadir sentinels, booleans intermedios ni estados de "operación en curso" cuando `nonReentrant` ya bloquea la re-entrada a nivel EVM. La complejidad extra solo se justifica si aporta una propiedad que la herramienta de seguridad existente no cubre.
- **CEI cuando el state depende del retorno de una call externa** (trilemma): cuando un Effect necesita el valor devuelto por una Interaction (e.g. `tokenId` de `mint()`), el patrón es: Effects independientes primero → Interaction que devuelve el dato → Effect dependiente → Interactions restantes. El state crítico queda escrito antes de la call al token externo. Ver `depositToken` en `StakingApp.sol`.
- **Single source of truth**: un dato tiene una sola fuente canónica. En `StakingApp`, `userTokenId` se escribe una sola vez y su valor proviene exclusivamente del return de `mint()`.
- En frontend: hooks de contrato separados de componentes UI. ABIs importados con `as const`. Estado de transacción explícito en cada acción (idle → pending → confirming → success/error).

## Skills disponibles

- **`design-taste-frontend`** — UI con dirección artística real y verificación visual en navegador. Usar al inicio de la Fase 3. Instalar: `/plugin marketplace add Leonxlnx/taste-skill` (comando manual en el prompt)
- **`vercel-react-best-practices`** ✅ — 40+ reglas de optimización para React y Next.js. Aplicar durante toda la Fase 3.
- **`web-design-guidelines`** ✅ — 100+ reglas de accesibilidad, UX y rendimiento. Usar junto a `design-taste-frontend` para revisar resultados.
- **`vercel-composition-patterns`** ✅ — patrones de composición React para evitar props bombing. Aplicar en componentes compartidos y panel admin.
- **`deploy-to-vercel`** ✅ — despliega el frontend a Vercel y devuelve URL pública lista para compartir con recruiters. Usar al final de la Fase 3.

## Git Conventions

- Do not add `Co-Authored-By` lines to commit messages.

## Security Patterns

- **CEI en `depositToken`**: `lastActivity` (Effect independiente) → `mint()` (Interaction, devuelve tokenId) → `userTokenId = tokenId` (Effect dependiente) → `safeTransferFrom` (Interaction del token externo). El state crítico queda escrito antes de la call al token.
- **CEI en `withdrawTokens`**: `delete userTokenId` y `delete lastActivity` antes de `burn()` y `safeTransfer()`.
- **`nonReentrant` como red de seguridad**: cubre el gap entre `mint()` y la escritura de `userTokenId`. No sustituye CEI — es defensa en profundidad.
- All custom errors include parameters (`IncorrectAmount(expected, provided)`, `StakingPeriodNotElapsed(remaining)`) for debuggability.
- `receive()` is `onlyOwner` to prevent accidental ETH from third parties.
- Pause disables `depositToken` and `claimRewards` but never `withdrawTokens` — users can always exit.

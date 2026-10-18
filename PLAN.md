# Staking Protocol — Roadmap

> Estado actualizado por el agente al completar cada tarea.
> Leyenda: 🔲 pendiente · ⏳ en progreso · ✅ completado

---

## Decisiones de arquitectura

- **EIP-721 como recibo de posición**: al depositar tokens, se mintea un NFT al usuario que representa su posición (stakeAmount + timestamp). Quien tenga el NFT puede hacer claim y withdraw. Patrón usado en producción por Uniswap v3.
- **Frontend**: scaffold-eth 2 (wagmi v2 + viem + Next.js) conectado a Sepolia.
- **Chainlink**: price feed ETH/USD para mostrar el valor en dólares de las rewards.
- **L2**: deploy en Base Sepolia o Arbitrum Sepolia además de Sepolia mainnet-test.
- **Sin EIP-712 / UUPS en esta iteración**: mantener el contrato enfocado y auditable.

---

## Principios de ingeniería (aplican a todas las fases)

### Solidity
- **Single Responsibility**: cada contrato tiene una responsabilidad única (`StakingToken` emite tokens, `StakingNFT` gestiona posiciones, `StakingApp` orquesta la lógica de staking).
- **Custom errors con parámetros** en todos los reverts — nunca `require` con strings.
- **Sin magic numbers**: todas las constantes nombradas (`MAX_SUPPLY`, `BASIS_POINTS`, etc.).
- **NatSpec completo** en todas las funciones públicas y eventos.
- **CEI estricto** (Check-Effects-Interactions) en cualquier función que haga transferencias.
- **Immutable** para variables que no cambian tras el deploy — lectura más barata y documenta intención.
- **Events indexados** en todos los parámetros que se usarán para filtrar off-chain.

### Testing
- **Patrón AAA obligatorio** en todos los tests: bloques `// Arrange`, `// Act`, `// Assert` explícitos y separados — nunca mezclar setup con aserciones.
- **Un test, una aserción conceptual**: cada test verifica una sola cosa. Si falla, el nombre del test dice exactamente qué falló.
- **Nomenclatura**: `test_<función>_<escenario>_<resultado esperado>` — e.g. `test_depositToken_whenAlreadyDeposited_revertsWithAlreadyDeposited`.
- **Cobertura por tipo**:
  - *Unit*: happy path + cada revert posible + cada rama de control de acceso.
  - *Fuzz*: una función de fuzz por cada parámetro numérico que pueda tomar valores extremos.
  - *Invariant*: una por cada propiedad global que debe ser siempre verdadera, con handler que restringe las llamadas a estado válido.
  - *Integration*: flujos completos de extremo a extremo (deposit → wait → claim → withdraw).
- **Sin tests acoplados**: cada test arranca desde `setUp` limpio, nunca depende del orden de ejecución.
- **Cobertura de líneas al 100%** mantenida en todo momento — `forge coverage` como gate en CI.

### Frontend
- **Separación de capas**: hooks de contrato (`useStakingApp`, `useStakingNFT`) separados de los componentes UI — nunca lógica de contrato dentro de un componente.
- **Tipado estricto**: ABIs importados como `const` con `as const` para inferencia de tipos completa via viem.
- **Estado de transacción explícito**: idle → pending → confirming → success/error en cada acción, nunca asumir que una tx confirmada en el cliente es final.
- **Errores legibles**: mapear los custom errors del contrato a mensajes de usuario en una capa centralizada.
- **Sin lógica duplicada**: si algo se calcula en el contrato (tiempo restante, elegibilidad), leerlo del contrato — no recalcularlo en el frontend.

### Mentoría
- **No dar nada por entendido**: antes de implementar cualquier concepto nuevo (patrón, estándar, tool), explicar qué es, por qué se usa y qué problema resuelve — en 2-4 líneas, sin jerga innecesaria.
- **Explicar el por qué antes del cómo**: no solo escribir el código sino razonar la decisión de diseño tomada.
- **Señalar conexiones**: cuando un concepto nuevo se relacione con algo ya visto en el proyecto, indicarlo explícitamente.
- **Progresión consciente**: al terminar cada fase, resumir qué se aprendió y qué habilidades se han añadido al perfil.

### Git
- Un commit por tarea del plan, mensaje en formato `type: descripción` (Conventional Commits).
- Actualizar `PLAN.md` en el mismo commit que completa la tarea.
- No commitear sin confirmación explícita del usuario.

---

## Fase 1 — Solidity: NFT Staking Position (EIP-721)

> Objetivo: cada posición de staking es un ERC-721. El contrato StakingApp mintea y quema NFTs en lugar de trackear balances por address.

### Contratos

- 🔲 Crear `src/StakingNFT.sol`
  - ERC-721 con metadata on-chain (tokenId, amount, depositTimestamp)
  - Solo `StakingApp` puede mint y burn (control de acceso por role o por address)
  - `tokenURI` generado on-chain en base64 (SVG simple con los datos de la posición)

- 🔲 Refactorizar `src/StakingApp.sol`
  - Reemplazar `mapping(address => uint256) userBalance` por `mapping(address => uint256) userTokenId`
  - `depositToken` → mintea NFT al depositante, guarda `tokenId`
  - `withdrawTokens` → burn del NFT, devuelve tokens
  - `claimRewards` → verifica que `msg.sender` es el owner del NFT de su posición
  - Mantener todas las guards actuales (ReentrancyGuard, Pausable, CEI)

### Tests

- 🔲 Actualizar `test/StakingAppTest.t.sol` para el nuevo flujo con NFT
- 🔲 Actualizar `test/StakingAppFuzz.t.sol`
- 🔲 Actualizar `test/StakingAppInvariant.t.sol` — el invariante ahora es: `totalSupply(NFT) * fixStakingAmount == tokenBalance(StakingApp)`
- 🔲 Añadir `test/StakingNFTTest.t.sol` — mint, burn, metadata, access control
- 🔲 Mantener 100% de cobertura de líneas

### CI

- 🔲 Actualizar `.gas-snapshot` tras los cambios
- 🔲 Verificar que Slither no introduce nuevos findings

---

## Fase 2 — Deploy en Sepolia

> Objetivo: contratos desplegados en testnet pública, verificados en Etherscan.

- 🔲 Actualizar `script/Deploy.s.sol` para desplegar también `StakingNFT`
- 🔲 Deploy en Sepolia con `forge script --broadcast --verify`
- 🔲 Verificar ambos contratos en Etherscan Sepolia
- 🔲 Actualizar `.env.example` con las nuevas variables necesarias
- 🔲 Documentar addresses desplegadas en este archivo

**Addresses Sepolia:**
```
StakingToken : (pendiente)
StakingNFT   : (pendiente)
StakingApp   : (pendiente)
```

---

## Fase 3 — Frontend (scaffold-eth 2)

> Objetivo: app funcional conectada a Sepolia. Tres rutas, wallet persistente.

### Setup

- 🔲 Inicializar scaffold-eth 2 en `/frontend`
- 🔲 Conectar ABIs generados por Foundry (`out/`) al frontend
- 🔲 Configurar red Sepolia como default

### Ruta `/` — My Position

- 🔲 Conectar wallet (RainbowKit incluido en scaffold-eth 2)
- 🔲 Mostrar estado: sin posición / posición activa
- 🔲 Si tiene posición: mostrar NFT (imagen SVG generada on-chain), tokens stakeados, countdown al próximo claim
- 🔲 Botones: `Deposit`, `Claim` (disabled hasta que el período haya pasado), `Withdraw`
- 🔲 Estados de transacción: pending → confirming → confirmed con toast
- 🔲 Mapear custom errors del contrato a mensajes legibles

### Ruta `/activity` — Protocol Activity

- 🔲 Tabla de eventos: `DepositTokens`, `WithdrawTokens`, `RewardsClaimed`
- 🔲 Filtro por wallet (por defecto filtra la wallet conectada, opción "ver todo")
- 🔲 Chainlink ETH/USD feed para mostrar valor en USD de cada reward claim

### Ruta `/admin` — Owner Panel

- 🔲 Visible solo si `address === owner`
- 🔲 Pause / Unpause
- 🔲 Cambiar staking period
- 🔲 Enviar ETH al contrato (fund rewards)
- 🔲 Balance ETH del contrato en tiempo real

---

## Fase 4 — L2 Deploy

> Objetivo: mismo contrato en una L2, selector de red en el frontend.

- 🔲 Deploy en Base Sepolia (o Arbitrum Sepolia)
- 🔲 Verificar en el explorer correspondiente
- 🔲 Añadir selector de red al frontend (Sepolia ↔ Base Sepolia)
- 🔲 Documentar addresses L2 aquí

**Addresses Base Sepolia:**
```
StakingToken : (pendiente)
StakingNFT   : (pendiente)
StakingApp   : (pendiente)
```

---

## Registro de cambios

| Fecha | Fase | Acción |
|---|---|---|
| 2026-10-18 | — | Plan creado |

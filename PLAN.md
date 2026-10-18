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

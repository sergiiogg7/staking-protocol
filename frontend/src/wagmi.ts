import { createConfig, http } from "wagmi";
import { foundry } from "wagmi/chains";
import { injected } from "wagmi/connectors";

// The single source of truth wagmi reads from: which chains the app supports, how to reach each
// one (transport) and which wallets can connect (connectors). Only the local Anvil chain for now;
// Sepolia is added here when the contracts are deployed there.
export const config = createConfig({
  chains: [foundry],
  // `injected()` connects to whatever wallet the browser exposes (MetaMask, Rabby, Brave Wallet...).
  connectors: [injected()],
  transports: { [foundry.id]: http() },
});

// Registers this config's types with wagmi, so every hook knows the supported chain ids.
declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}

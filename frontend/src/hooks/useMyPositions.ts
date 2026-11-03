import { useQuery } from "@tanstack/react-query";
import { useAccount, useChainId, useConfig } from "wagmi";
import { getReceivedTokenIds, readPositions } from "../lib/positions.ts";

// The open positions of the connected wallet. The logic lives in lib/positions.ts as plain functions
// (so it can be tested without React); this hook only wires it to wagmi's config and to the query cache.
export function useMyPositions() {
  const config = useConfig();
  const chainId = useChainId();
  const { address } = useAccount();

  return useQuery({
    // Wallet and chain are part of the key: switching either one is a different cache entry, so
    // positions of the previous account are never shown.
    queryKey: ["myPositions", chainId, address],
    queryFn: async () => {
      if (!address) throw new Error("No wallet connected");
      const received = await getReceivedTokenIds(config, address);
      return readPositions(config, address, received);
    },
    // Without a connected wallet there is nothing to ask for.
    enabled: address !== undefined,
  });
}

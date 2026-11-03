import { useQuery } from "@tanstack/react-query";
import { useAccount, useChainId, useConfig } from "wagmi";
import { getActivity } from "../lib/activity.ts";

export type ActivityScope = "mine" | "all";

// The event log of the protocol. The scope and the wallet are part of the key, so "mine" for one account and
// "all" are separate cache entries and switching between them is instant once both have been loaded.
export function useActivity(scope: ActivityScope) {
  const config = useConfig();
  const chainId = useChainId();
  const { address } = useAccount();
  const wallet = scope === "mine" ? address : undefined;

  return useQuery({
    queryKey: ["activity", chainId, scope, wallet],
    queryFn: () => getActivity(config, wallet),
    // "mine" needs a connected wallet; "all" does not.
    enabled: scope === "all" || address !== undefined,
  });
}

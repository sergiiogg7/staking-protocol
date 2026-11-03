import { useReadContracts } from "wagmi";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { localAddresses } from "../contracts.ts";

const stakingApp = { address: localAddresses.stakingApp, abi: stakingAppAbi } as const;

// The protocol's settings. Three of them are immutable, so they never change; `paused` can, which is
// why this is a query that refetches rather than a constant.
export function useStakingConfig() {
  const { data, ...query } = useReadContracts({
    contracts: [
      { ...stakingApp, functionName: "stakingPeriod" },
      { ...stakingApp, functionName: "fixStakingAmount" },
      { ...stakingApp, functionName: "rewardPerPeriod" },
      { ...stakingApp, functionName: "paused" },
    ],
    // false: either every read succeeds or the query fails as a whole, and `data` is a plain typed tuple.
    allowFailure: false,
  });

  const [stakingPeriod, fixStakingAmount, rewardPerPeriod, paused] = data ?? [];

  return { stakingPeriod, fixStakingAmount, rewardPerPeriod, paused, ...query };
}

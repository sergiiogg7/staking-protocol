import { formatEther, formatUnits } from "viem";
import { useStakingConfig } from "../hooks/useStakingConfig.ts";

export function ProtocolStats() {
  const { stakingPeriod, fixStakingAmount, rewardPerPeriod, paused, isPending, error } = useStakingConfig();

  if (isPending) return <p>Loading protocol settings…</p>;
  // `error` also covers the node being down, which is the usual local-development failure.
  if (error || stakingPeriod === undefined) return <p className="error">Could not read the protocol: {error?.message}</p>;

  return (
    <dl className="stats">
      <dt>Stake per position</dt>
      <dd>{formatUnits(fixStakingAmount ?? 0n, 18)} STK</dd>
      <dt>Reward per period</dt>
      <dd>{formatEther(rewardPerPeriod ?? 0n)} ETH</dd>
      <dt>Period</dt>
      <dd>{stakingPeriod.toString()} seconds</dd>
      <dt>Status</dt>
      <dd>{paused ? "Paused" : "Active"}</dd>
    </dl>
  );
}

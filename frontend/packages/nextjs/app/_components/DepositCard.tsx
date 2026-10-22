"use client";

import { formatUnits } from "viem";
import { useDeployedContractInfo, useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

type Props = {
  address: `0x${string}`;
};

function formatPeriod(seconds: bigint): string {
  if (seconds >= 86400n) return `${Number(seconds) / 86400} days`;
  if (seconds >= 3600n) return `${Number(seconds) / 3600}h`;
  if (seconds >= 60n) return `${Number(seconds) / 60}m`;
  return `${Number(seconds)}s`;
}

export function DepositCard({ address }: Props) {
  const { data: stakingAppInfo } = useDeployedContractInfo({ contractName: "StakingApp" });

  const { data: fixStakingAmount } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "fixStakingAmount",
  });

  const { data: rewardPerPeriod } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "rewardPerPeriod",
  });

  const { data: stakingPeriod } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "stakingPeriod",
  });

  const { data: balance } = useScaffoldReadContract({
    contractName: "StakingToken",
    functionName: "balanceOf",
    args: [address],
  });

  const { data: allowance } = useScaffoldReadContract({
    contractName: "StakingToken",
    functionName: "allowance",
    args: [address, stakingAppInfo?.address],
    query: { enabled: !!stakingAppInfo?.address },
  });

  const { writeContractAsync: approveToken, isMining: isApproving } = useScaffoldWriteContract({
    contractName: "StakingToken",
  });
  const { writeContractAsync: writeStakingApp, isMining: isDepositing } = useScaffoldWriteContract({
    contractName: "StakingApp",
  });

  const isApproved = allowance !== undefined && fixStakingAmount !== undefined && allowance >= fixStakingAmount;
  const hasEnoughBalance = balance !== undefined && fixStakingAmount !== undefined && balance >= fixStakingAmount;
  const isBusy = isApproving || isDepositing;

  const formattedAmount = fixStakingAmount ? formatUnits(fixStakingAmount, 18) : "—";
  const formattedBalance = balance !== undefined ? formatUnits(balance, 18) : "—";
  const formattedReward = rewardPerPeriod ? formatUnits(rewardPerPeriod, 18) : "—";
  const formattedPeriod = stakingPeriod ? formatPeriod(stakingPeriod) : "—";

  return (
    <div className="card bg-base-100 shadow-xl w-full max-w-sm">
      <div className="card-body gap-6">
        <div>
          <h2 className="card-title text-2xl">STK Staking</h2>
          <p className="text-base-content/50 text-sm mt-1">Stake tokens, earn ETH rewards each period</p>
        </div>

        <div className="grid grid-cols-2 gap-y-2 text-sm bg-base-200 rounded-xl px-4 py-3">
          <span className="text-base-content/50">Required</span>
          <span className="font-mono font-medium text-right">{formattedAmount} STK</span>
          <span className="text-base-content/50">Your balance</span>
          <span
            className={`font-mono font-medium text-right ${!hasEnoughBalance && balance !== undefined ? "text-error" : ""}`}
          >
            {formattedBalance} STK
          </span>
          <span className="text-base-content/50">Reward</span>
          <span className="font-mono font-medium text-right">{formattedReward} ETH</span>
          <span className="text-base-content/50">Period</span>
          <span className="font-mono font-medium text-right">{formattedPeriod}</span>
        </div>

        <div className="card-actions flex-col gap-2">
          {!isApproved ? (
            <button
              className="btn btn-primary w-full"
              disabled={!hasEnoughBalance || isBusy}
              onClick={() =>
                approveToken({
                  functionName: "approve",
                  args: [stakingAppInfo?.address, fixStakingAmount],
                })
              }
            >
              {isApproving ? <span className="loading loading-spinner loading-sm" /> : null}
              {hasEnoughBalance ? "Approve STK" : "Insufficient balance"}
            </button>
          ) : (
            <button
              className="btn btn-primary w-full"
              disabled={isBusy}
              onClick={() =>
                writeStakingApp({
                  functionName: "depositToken",
                  args: [fixStakingAmount],
                })
              }
            >
              {isDepositing ? <span className="loading loading-spinner loading-sm" /> : null}
              Deposit {formattedAmount} STK
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

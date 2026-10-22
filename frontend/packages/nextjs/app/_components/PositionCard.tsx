"use client";

import { useEffect, useState } from "react";
import { formatUnits } from "viem";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

type Props = {
  address: `0x${string}`;
  tokenId: bigint;
};

function formatCountdown(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function extractImage(tokenURI: string): string {
  const json = JSON.parse(atob(tokenURI.replace("data:application/json;base64,", "")));
  return json.image as string;
}

export function PositionCard({ address, tokenId }: Props) {
  const [secondsLeft, setSecondsLeft] = useState<number | null>(null);

  const { data: tokenURI } = useScaffoldReadContract({
    contractName: "StakingNFT",
    functionName: "tokenURI",
    args: [tokenId],
  });

  const { data: depositAmount } = useScaffoldReadContract({
    contractName: "StakingNFT",
    functionName: "depositAmount",
    args: [tokenId],
  });

  const { data: lastActivity } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "lastActivity",
    args: [address],
  });

  const { data: stakingPeriod } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "stakingPeriod",
  });

  const { writeContractAsync, isMining } = useScaffoldWriteContract({ contractName: "StakingApp" });

  useEffect(() => {
    if (!lastActivity || !stakingPeriod) return;
    const update = () => {
      const elapsed = Math.floor(Date.now() / 1000) - Number(lastActivity);
      setSecondsLeft(Math.max(0, Number(stakingPeriod) - elapsed));
    };
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  }, [lastActivity, stakingPeriod]);

  const imageUri = tokenURI ? extractImage(tokenURI) : null;
  const canClaim = secondsLeft === 0;
  const formattedAmount = depositAmount ? formatUnits(depositAmount, 18) : "—";

  return (
    <div className="card bg-base-100 shadow-xl w-full max-w-sm">
      <figure className="px-6 pt-6">
        {imageUri ? (
          <img src={imageUri} alt={`STK Position #${tokenId}`} className="rounded-xl w-full" />
        ) : (
          <div className="skeleton w-full h-72 rounded-xl" />
        )}
      </figure>

      <div className="card-body gap-4">
        <h2 className="card-title">Position #{tokenId.toString()}</h2>

        <div className="grid grid-cols-2 gap-y-2 text-sm bg-base-200 rounded-xl px-4 py-3">
          <span className="text-base-content/50">Staked</span>
          <span className="font-mono font-medium text-right">{formattedAmount} STK</span>
          <span className="text-base-content/50">Next claim</span>
          <span className="font-mono font-medium text-right tabular-nums">
            {secondsLeft === null ? "—" : secondsLeft === 0 ? "Ready ✓" : formatCountdown(secondsLeft)}
          </span>
        </div>

        <div className="card-actions flex-col gap-2">
          <button
            className="btn btn-primary w-full"
            disabled={!canClaim || isMining}
            onClick={() => writeContractAsync({ functionName: "claimRewards" })}
          >
            {isMining ? <span className="loading loading-spinner loading-sm" /> : null}
            Claim rewards
          </button>
          <button
            className="btn btn-outline w-full"
            disabled={isMining}
            onClick={() => writeContractAsync({ functionName: "withdrawTokens" })}
          >
            Withdraw
          </button>
        </div>
      </div>
    </div>
  );
}

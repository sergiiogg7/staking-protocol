import { formatEther } from "viem";
import { useClaim, useWithdraw } from "../hooks/useStakingActions.ts";
import type { Position } from "../lib/positions.ts";
import { TransactionStatus } from "./TransactionStatus.tsx";

interface Props {
  position: Position;
  // ETH held by the contract, or undefined while it is still being read.
  contractBalance: bigint | undefined;
}

export function PositionActions({ position, contractBalance }: Props) {
  const claim = useClaim();
  const withdraw = useWithdraw();

  const busy = claim.isBusy || withdraw.isBusy;
  const nothingToClaim = position.claimable === 0n;
  // A claim pays the whole amount or reverts, so claiming more than the contract holds is bound to fail.
  const underfunded = contractBalance !== undefined && position.claimable > contractBalance;

  return (
    <div className="actions">
      {underfunded && (
        <p className="warning">
          The contract holds {formatEther(contractBalance)} ETH but this position has earned{" "}
          {formatEther(position.claimable)} ETH. A claim would fail until the owner funds the contract.
        </p>
      )}
      <button disabled={busy || nothingToClaim || underfunded} onClick={() => claim.execute(position.tokenId)}>
        Claim
      </button>
      <button className="secondary" disabled={busy} onClick={() => withdraw.execute(position.tokenId)}>
        Withdraw
      </button>
      <TransactionStatus phase={claim.phase} step={claim.step} hash={claim.hash} error={claim.error} />
      <TransactionStatus phase={withdraw.phase} step={withdraw.step} hash={withdraw.hash} error={withdraw.error} />
    </div>
  );
}

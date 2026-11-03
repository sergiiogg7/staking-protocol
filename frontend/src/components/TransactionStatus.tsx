import type { Hash } from "viem";
import type { TxPhase } from "../hooks/useTransaction.ts";

interface Props {
  phase: TxPhase;
  step: string | undefined;
  hash: Hash | undefined;
  error: string | undefined;
}

// One message per phase of an action. The switch is exhaustive: adding a phase without handling it
// here is a compile error.
export function TransactionStatus({ phase, step, hash, error }: Props) {
  switch (phase) {
    case "idle":
      return null;
    case "pending":
      return <p>{step ? `${step}: ` : ""}confirm in your wallet…</p>;
    case "confirming":
      return (
        <p>
          Waiting for confirmation… <code title={hash}>{hash?.slice(0, 10)}…</code>
        </p>
      );
    case "success":
      return <p className="success">Done.</p>;
    case "error":
      return <p className="error">{error}</p>;
  }
}

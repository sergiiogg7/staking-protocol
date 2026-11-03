import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import type { Hash } from "viem";
import { describeError } from "../lib/errors.ts";
import type { Progress } from "../lib/transactions.ts";

// idle: nothing started. pending: waiting for the user to sign. confirming: sent, waiting to be mined.
export type TxPhase = "idle" | "pending" | "confirming" | "success" | "error";

// The state machine of one action. `run` does the work (simulate, send, wait) and reports progress through
// callbacks; this hook turns those reports into state a component can render, and refreshes the cache.
export function useTransaction<Variables = void>(run: (variables: Variables, progress: Progress) => Promise<unknown>) {
  const queryClient = useQueryClient();
  const [phase, setPhase] = useState<TxPhase>("idle");
  const [step, setStep] = useState<string>();
  const [hash, setHash] = useState<Hash>();
  const [error, setError] = useState<string>();

  async function execute(variables: Variables) {
    setPhase("pending");
    setStep(undefined);
    setHash(undefined);
    setError(undefined);

    try {
      await run(variables, {
        // A multi-transaction action announces each step; the next one waits for a new signature.
        step: (label) => {
          setStep(label);
          setPhase("pending");
        },
        sent: (sentHash) => {
          setHash(sentHash);
          setPhase("confirming");
        },
      });
      setPhase("success");
      // The chain changed: positions and balances read before are now stale.
      await queryClient.invalidateQueries({ queryKey: ["myPositions"] });
      await queryClient.invalidateQueries({ queryKey: ["balance"] });
      // Contract reads such as the paused flag or the number of open positions.
      await queryClient.invalidateQueries({ queryKey: ["readContracts"] });
    } catch (caught) {
      setError(describeError(caught));
      setPhase("error");
    }
  }

  return { phase, step, hash, error, execute, isBusy: phase === "pending" || phase === "confirming" };
}

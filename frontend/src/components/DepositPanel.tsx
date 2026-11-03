import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { useStakingConfig } from "../hooks/useStakingConfig.ts";
import { useDeposit } from "../hooks/useStakingActions.ts";
import { TransactionStatus } from "./TransactionStatus.tsx";

export function DepositPanel() {
  // All hooks run before the early return: hooks must be called in the same order on every render.
  const { isConnected } = useAccount();
  const { fixStakingAmount } = useStakingConfig();
  const deposit = useDeposit();

  if (!isConnected) return null;

  return (
    <section className="actions">
      <button disabled={deposit.isBusy || fixStakingAmount === undefined} onClick={() => deposit.execute()}>
        {fixStakingAmount === undefined ? "Deposit" : `Deposit ${formatUnits(fixStakingAmount, 18)} STK`}
      </button>
      <TransactionStatus phase={deposit.phase} step={deposit.step} hash={deposit.hash} error={deposit.error} />
    </section>
  );
}

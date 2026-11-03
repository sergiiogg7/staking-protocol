import { useState } from "react";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { ProtocolStats } from "../components/ProtocolStats.tsx";
import { TransactionStatus } from "../components/TransactionStatus.tsx";
import { useAdminData } from "../hooks/useAdminData.ts";
import { useFund, usePause, useUnpause, useWithdrawEther } from "../hooks/useStakingActions.ts";
import { parseEthAmount } from "../lib/amount.ts";

export function AdminPage() {
  // Every hook runs before the early returns below: hooks must be called in the same order on every render.
  const { isConnected } = useAccount();
  const admin = useAdminData();
  const pauseAction = usePause();
  const unpauseAction = useUnpause();
  const withdraw = useWithdrawEther();
  const fund = useFund();
  // A controlled input: React state is the source of truth for the text, and the field only displays it.
  const [amountText, setAmountText] = useState("");

  if (!isConnected) return <p>Connect your wallet to open the admin panel.</p>;
  if (admin.isPending) return <p>Loading the contract state…</p>;
  if (admin.error) return <p className="error">Could not read the contract: {admin.error.message}</p>;
  // This only hides buttons that would fail. It is not security: anyone can call the contract directly,
  // and what really stops them is `onlyOwner` in the contract.
  if (!admin.isOwner) return <p>This panel is only for the contract owner ({admin.owner}).</p>;

  const isPaused = admin.paused === true;
  const toggle = isPaused ? unpauseAction : pauseAction;
  const amount = parseEthAmount(amountText);
  const busy = pauseAction.isBusy || unpauseAction.isBusy || withdraw.isBusy || fund.isBusy;

  const openPositions = admin.openPositions ?? 0n;
  const balance = admin.balance ?? 0n;
  const withdrawBlockedBy =
    openPositions > 0n ? `${openPositions} position(s) are still open` : balance === 0n ? "the contract holds no ETH" : undefined;

  return (
    <section className="admin">
      <h2>Contract state</h2>
      <dl className="stats">
        <dt>Status</dt>
        <dd>{isPaused ? "Paused" : "Active"}</dd>
        <dt>Open positions</dt>
        <dd>{openPositions.toString()}</dd>
        <dt>ETH in the contract</dt>
        <dd>{formatEther(balance)} ETH</dd>
      </dl>

      <h2>Pause</h2>
      <p>Pausing disables deposits and claims. Withdrawals always stay open.</p>
      <div className="actions">
        <button disabled={busy} onClick={() => toggle.execute()}>
          {isPaused ? "Unpause" : "Pause"}
        </button>
        <TransactionStatus phase={toggle.phase} step={toggle.step} hash={toggle.hash} error={toggle.error} />
      </div>

      <h2>Fund the rewards</h2>
      <div className="actions">
        <input
          value={amountText}
          onChange={(event) => setAmountText(event.target.value)}
          inputMode="decimal"
          placeholder="0.5"
          aria-label="ETH amount to send"
        />
        <button disabled={busy || amount === undefined} onClick={() => amount !== undefined && fund.execute(amount)}>
          Send ETH
        </button>
        {amountText !== "" && amount === undefined && <p className="warning">Enter a positive amount of ETH.</p>}
        <TransactionStatus phase={fund.phase} step={fund.step} hash={fund.hash} error={fund.error} />
      </div>

      <h2>Withdraw the ETH</h2>
      <p>The contract only lets the owner take the ETH back when no position is open.</p>
      <div className="actions">
        <button disabled={busy || withdrawBlockedBy !== undefined} onClick={() => withdraw.execute()}>
          Withdraw all ETH
        </button>
        {withdrawBlockedBy && <p className="warning">Not available: {withdrawBlockedBy}.</p>}
        <TransactionStatus phase={withdraw.phase} step={withdraw.step} hash={withdraw.hash} error={withdraw.error} />
      </div>

      <h2>Settings fixed at deployment</h2>
      <ProtocolStats />
    </section>
  );
}

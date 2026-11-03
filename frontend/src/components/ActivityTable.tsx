import { formatEther, formatUnits } from "viem";
import type { ActivityItem } from "../lib/activity.ts";

const shorten = (value: string) => `${value.slice(0, 6)}…${value.slice(-4)}`;

// Pure presentation: it receives the events and draws them, so it can be checked without any wallet or chain.
export function ActivityTable({ items }: { items: readonly ActivityItem[] }) {
  if (items.length === 0) return <p>No activity yet.</p>;

  return (
    <table className="activity">
      <thead>
        <tr>
          <th scope="col">Date</th>
          <th scope="col">Event</th>
          <th scope="col">Wallet</th>
          <th scope="col">Position</th>
          <th scope="col">Amount</th>
          <th scope="col">Transaction</th>
        </tr>
      </thead>
      <tbody>
        {items.map((item) => (
          <tr key={item.id}>
            <td>{new Date(Number(item.timestamp) * 1000).toLocaleString()}</td>
            <td>{item.kind}</td>
            <td title={item.wallet}>{item.wallet ? shorten(item.wallet) : "—"}</td>
            <td>{item.tokenId === undefined ? "—" : `#${item.tokenId}`}</td>
            <td>
              {item.unit === "STK" ? formatUnits(item.amount, 18) : formatEther(item.amount)} {item.unit}
            </td>
            <td>
              <code title={item.txHash}>{shorten(item.txHash)}</code>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

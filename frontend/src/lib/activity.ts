import type { Address, Hash } from "viem";
import type { Config } from "wagmi";
import { getPublicClient } from "wagmi/actions";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { localAddresses } from "../contracts.ts";

export type ActivityKind = "Deposit" | "Withdraw" | "Claim" | "Funded" | "ETH withdrawn";

export interface ActivityItem {
  id: string;
  kind: ActivityKind;
  blockNumber: bigint;
  logIndex: number;
  txHash: Hash;
  timestamp: bigint;
  wallet?: Address;
  tokenId?: bigint;
  amount: bigint;
  unit: "STK" | "ETH";
}

type RawItem = Omit<ActivityItem, "timestamp">;

// The protocol's event log, newest first. With a wallet it is that wallet's own activity, found through the
// indexed address of each event (it is called userAddress_ in two events and user_ in the other, so one query
// per event). EtherSent and EtherWithdrawn have no indexed address, so they only appear in the full log.
// Reading from block 0 is fine on a local chain; on a real network start at the contract's deployment block.
export async function getActivity(config: Config, wallet?: Address): Promise<ActivityItem[]> {
  const client = getPublicClient(config);
  if (!client) throw new Error("No public client for the configured chain");

  const base = { address: localAddresses.stakingApp, abi: stakingAppAbi, fromBlock: 0n } as const;
  const [deposits, withdrawals, claims, funded, taken] = await Promise.all([
    client.getContractEvents({ ...base, eventName: "DepositTokens", args: wallet ? { userAddress_: wallet } : undefined }),
    client.getContractEvents({ ...base, eventName: "WithdrawTokens", args: wallet ? { userAddress_: wallet } : undefined }),
    client.getContractEvents({ ...base, eventName: "RewardsClaimed", args: wallet ? { user_: wallet } : undefined }),
    wallet ? [] : client.getContractEvents({ ...base, eventName: "EtherSent" }),
    wallet ? [] : client.getContractEvents({ ...base, eventName: "EtherWithdrawn" }),
  ]);

  const items: RawItem[] = [
    ...deposits.map((log) => ({
      kind: "Deposit" as const,
      wallet: log.args.userAddress_,
      tokenId: log.args.tokenId_,
      amount: log.args.depositAmount_ ?? 0n,
      unit: "STK" as const,
      ...where(log),
    })),
    ...withdrawals.map((log) => ({
      kind: "Withdraw" as const,
      wallet: log.args.userAddress_,
      tokenId: log.args.tokenId_,
      amount: log.args.withdrawAmount_ ?? 0n,
      unit: "STK" as const,
      ...where(log),
    })),
    ...claims.map((log) => ({
      kind: "Claim" as const,
      wallet: log.args.user_,
      amount: log.args.amount_ ?? 0n,
      unit: "ETH" as const,
      ...where(log),
    })),
    ...funded.map((log) => ({ kind: "Funded" as const, amount: log.args.amount_ ?? 0n, unit: "ETH" as const, ...where(log) })),
    ...taken.map((log) => ({
      kind: "ETH withdrawn" as const,
      amount: log.args.amount_ ?? 0n,
      unit: "ETH" as const,
      ...where(log),
    })),
  ];

  // A log carries its block number, not its date: ask once for each distinct block.
  const blocks = [...new Set(items.map((item) => item.blockNumber))];
  const timestamps = new Map(
    await Promise.all(blocks.map(async (blockNumber) => [blockNumber, (await client.getBlock({ blockNumber })).timestamp] as const)),
  );

  return items
    .map((item) => ({ ...item, timestamp: timestamps.get(item.blockNumber) ?? 0n }))
    .sort((a, b) => (a.blockNumber === b.blockNumber ? b.logIndex - a.logIndex : a.blockNumber > b.blockNumber ? -1 : 1));
}

// Where in the chain an event happened. These fields are only null for pending logs, which a history never has.
function where(log: { blockNumber: bigint; logIndex: number; transactionHash: Hash }) {
  return {
    id: `${log.transactionHash}-${log.logIndex}`,
    blockNumber: log.blockNumber,
    logIndex: log.logIndex,
    txHash: log.transactionHash,
  };
}

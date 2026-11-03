import { useAccount, useConfig } from "wagmi";
import { claimRewards, deposit, withdrawTokens } from "../lib/transactions.ts";
import { useTransaction } from "./useTransaction.ts";

// One hook per action. Each returns the state machine of useTransaction plus its `execute` function.

export function useDeposit() {
  const config = useConfig();
  const { address } = useAccount();

  return useTransaction(async (_: void, progress) => {
    if (!address) throw new Error("Connect your wallet first.");
    await deposit(config, address, progress);
  });
}

export function useClaim() {
  const config = useConfig();
  return useTransaction(async (tokenId: bigint, progress) => {
    await claimRewards(config, tokenId, progress);
  });
}

export function useWithdraw() {
  const config = useConfig();
  return useTransaction(async (tokenId: bigint, progress) => {
    await withdrawTokens(config, tokenId, progress);
  });
}

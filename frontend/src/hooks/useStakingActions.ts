import { useAccount, useConfig } from "wagmi";
import {
  claimRewards,
  deposit,
  fundContract,
  pause,
  unpause,
  withdrawEther,
  withdrawTokens,
} from "../lib/transactions.ts";
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

// Owner actions, for the admin panel.

export function usePause() {
  const config = useConfig();
  return useTransaction(async (_: void, progress) => {
    await pause(config, progress);
  });
}

export function useUnpause() {
  const config = useConfig();
  return useTransaction(async (_: void, progress) => {
    await unpause(config, progress);
  });
}

export function useWithdrawEther() {
  const config = useConfig();
  return useTransaction(async (_: void, progress) => {
    await withdrawEther(config, progress);
  });
}

export function useFund() {
  const config = useConfig();
  return useTransaction(async (amount: bigint, progress) => {
    await fundContract(config, amount, progress);
  });
}

import type { Address, Hash } from "viem";
import type { Config } from "wagmi";
import { readContract, simulateContract, waitForTransactionReceipt, writeContract } from "wagmi/actions";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingTokenAbi } from "../abi/stakingToken.ts";
import { localAddresses } from "../contracts.ts";

const stakingApp = { address: localAddresses.stakingApp, abi: stakingAppAbi } as const;
const stakingToken = { address: localAddresses.stakingToken, abi: stakingTokenAbi } as const;

// What a running action reports back to whoever started it (the hook turns this into UI state).
export interface Progress {
  step: (label: string) => void;
  sent: (hash: Hash) => void;
}

// Send, then wait until the transaction is mined. A transaction can be mined and still have reverted.
async function submit(config: Config, send: () => Promise<Hash>, progress: Progress) {
  const hash = await send();
  progress.sent(hash);
  const receipt = await waitForTransactionReceipt(config, { hash });
  if (receipt.status === "reverted") throw new Error("The transaction was mined but reverted.");
  return receipt;
}

// Every write simulates first: if the call would revert, simulateContract throws a decoded error here,
// before the wallet asks the user to sign, so nobody pays gas for something that was going to fail.
export async function claimRewards(config: Config, tokenId: bigint, progress: Progress) {
  const { request } = await simulateContract(config, { ...stakingApp, functionName: "claimRewards", args: [tokenId] });
  return submit(config, () => writeContract(config, request), progress);
}

export async function withdrawTokens(config: Config, tokenId: bigint, progress: Progress) {
  const { request } = await simulateContract(config, { ...stakingApp, functionName: "withdrawTokens", args: [tokenId] });
  return submit(config, () => writeContract(config, request), progress);
}

// A deposit is two transactions: the token must first allow StakingApp to move the STK.
// The approval is for the exact amount, never unlimited, so a bug in StakingApp could not drain the wallet.
export async function deposit(config: Config, owner: Address, progress: Progress) {
  const amount = await readContract(config, { ...stakingApp, functionName: "fixStakingAmount" });
  const allowance = await readContract(config, {
    ...stakingToken,
    functionName: "allowance",
    args: [owner, localAddresses.stakingApp],
  });

  if (allowance < amount) {
    progress.step("Step 1 of 2, approve");
    const { request } = await simulateContract(config, {
      ...stakingToken,
      functionName: "approve",
      args: [localAddresses.stakingApp, amount],
    });
    await submit(config, () => writeContract(config, request), progress);
  }

  progress.step(allowance < amount ? "Step 2 of 2, deposit" : "Deposit");
  const { request } = await simulateContract(config, { ...stakingApp, functionName: "depositToken", args: [amount] });
  return submit(config, () => writeContract(config, request), progress);
}

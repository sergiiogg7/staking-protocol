// Why the ABI you pass decides which custom errors viem can name.
// Run with `node src/playground/errorDecoding.ts` (Anvil must be up).
import { BaseError, ContractFunctionRevertedError, createPublicClient, http } from "viem";
import { foundry } from "viem/chains";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { localAddresses } from "../contracts.ts";

const client = createPublicClient({ chain: foundry, transport: http() });
const staker = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

// claimRewards(999): StakingApp asks the NFT who owns token 999, and the NFT reverts with
// ERC721NonexistentToken. That error is defined in StakingNFT, not in StakingApp.
async function simulateClaim(abi: typeof stakingAppAbi | (typeof stakingAppAbi | typeof stakingNFTAbi)[number][]) {
  try {
    await client.simulateContract({
      address: localAddresses.stakingApp,
      abi: abi as typeof stakingAppAbi,
      functionName: "claimRewards",
      args: [999n],
      account: staker,
    });
  } catch (error) {
    const reverted = error instanceof BaseError ? error.walk((e) => e instanceof ContractFunctionRevertedError) : null;
    if (!(reverted instanceof ContractFunctionRevertedError)) throw error;
    return reverted;
  }
  throw new Error("expected a revert");
}

const withAppAbiOnly = await simulateClaim(stakingAppAbi);
console.log("StakingApp ABI only:");
console.log("  errorName :", withAppAbiOnly.data?.errorName);
console.log("  signature :", withAppAbiOnly.signature);

const withBothAbis = await simulateClaim([...stakingAppAbi, ...stakingNFTAbi]);
console.log("\nStakingApp + StakingNFT ABIs merged:");
console.log("  errorName :", withBothAbis.data?.errorName);
console.log("  args      :", withBothAbis.data?.args);

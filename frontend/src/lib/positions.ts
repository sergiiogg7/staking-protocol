import { isAddressEqual } from "viem";
import type { Address } from "viem";
import type { Config } from "wagmi";
import { getPublicClient, readContracts } from "wagmi/actions";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { localAddresses } from "../contracts.ts";

export interface Position {
  tokenId: bigint;
  depositAmount: bigint;
  depositTimestamp: bigint;
  lastActivity: bigint;
  claimable: bigint;
}

const stakingNFT = { address: localAddresses.stakingNFT, abi: stakingNFTAbi } as const;
const stakingApp = { address: localAddresses.stakingApp, abi: stakingAppAbi } as const;

// StakingNFT is not ERC721Enumerable, so the tokens of a wallet are rebuilt from its Transfer events.
// This returns every token the wallet has ever received: some may have been sold on or burned since.
// Reading from block 0 is fine on a local chain; on a real network start at the NFT's deployment block.
export async function getReceivedTokenIds(config: Config, owner: Address): Promise<bigint[]> {
  const client = getPublicClient(config);
  if (!client) throw new Error("No public client for the configured chain");

  const logs = await client.getContractEvents({
    ...stakingNFT,
    eventName: "Transfer",
    args: { to: owner },
    fromBlock: 0n,
  });

  // A token can be received more than once (sent away and back), so deduplicate.
  const tokenIds = new Set<bigint>();
  for (const log of logs) {
    if (log.args.tokenId !== undefined) tokenIds.add(log.args.tokenId);
  }
  return [...tokenIds];
}

// A log only proves a token was received, not that it is still held: ownerOf is the source of truth.
// ownerOf reverts for a burned token, so those reads are allowed to fail and are simply dropped.
export async function readPositions(config: Config, owner: Address, tokenIds: readonly bigint[]): Promise<Position[]> {
  if (tokenIds.length === 0) return [];

  const owners = await readContracts(config, {
    contracts: tokenIds.map((tokenId) => ({ ...stakingNFT, functionName: "ownerOf", args: [tokenId] }) as const),
    allowFailure: true,
  });
  const held = tokenIds.filter((_, index) => {
    const result = owners[index];
    return result?.status === "success" && isAddressEqual(result.result, owner);
  });
  if (held.length === 0) return [];

  const [depositAmounts, depositTimestamps, lastActivities, claimables] = await Promise.all([
    readContracts(config, {
      contracts: held.map((tokenId) => ({ ...stakingNFT, functionName: "depositAmount", args: [tokenId] }) as const),
      allowFailure: false,
    }),
    readContracts(config, {
      contracts: held.map((tokenId) => ({ ...stakingNFT, functionName: "depositTimestamp", args: [tokenId] }) as const),
      allowFailure: false,
    }),
    readContracts(config, {
      contracts: held.map((tokenId) => ({ ...stakingApp, functionName: "lastActivity", args: [tokenId] }) as const),
      allowFailure: false,
    }),
    readContracts(config, {
      contracts: held.map((tokenId) => ({ ...stakingApp, functionName: "claimableRewards", args: [tokenId] }) as const),
      allowFailure: false,
    }),
  ]);

  return held.map((tokenId, index) => ({
    tokenId,
    depositAmount: depositAmounts[index],
    depositTimestamp: depositTimestamps[index],
    lastActivity: lastActivities[index],
    claimable: claimables[index],
  }));
}

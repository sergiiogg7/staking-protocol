// Pure-viem exploration of the local deployment. No React, no wallet: just a client that talks to
// the Anvil node. Run it with `npm run playground:read` (Anvil must be up: `bash dev.sh`).
import { BaseError, ContractFunctionRevertedError, createPublicClient, formatEther, formatUnits, http } from "viem";
import { foundry } from "viem/chains";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { localAddresses } from "../contracts.ts";

// A public client only reads. `foundry` is viem's preset for Anvil: chain id 31337 and
// http://127.0.0.1:8545 as default RPC, so `http()` needs no URL.
const client = createPublicClient({ chain: foundry, transport: http() });

const staker = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

console.log("chainId:", await client.getChainId());
console.log("block  :", await client.getBlockNumber());

// 1. readContract = one eth_call. The ABI (`as const`) types the arguments and the result:
//    stakingPeriod is a bigint because the ABI says uint256.
const [stakingPeriod, fixStakingAmount, rewardPerPeriod, contractBalance] = await Promise.all([
  client.readContract({ address: localAddresses.stakingApp, abi: stakingAppAbi, functionName: "stakingPeriod" }),
  client.readContract({ address: localAddresses.stakingApp, abi: stakingAppAbi, functionName: "fixStakingAmount" }),
  client.readContract({ address: localAddresses.stakingApp, abi: stakingAppAbi, functionName: "rewardPerPeriod" }),
  client.getBalance({ address: localAddresses.stakingApp }),
]);
console.log("\n-- StakingApp --");
console.log("stakingPeriod   :", stakingPeriod, "seconds");
console.log("fixStakingAmount:", formatUnits(fixStakingAmount, 18), "STK");
console.log("rewardPerPeriod :", formatEther(rewardPerPeriod), "ETH");
console.log("ETH balance     :", formatEther(contractBalance), "ETH");

// 2. Positions of a wallet = Transfer events received by it, then ownerOf to see who holds each one now.
//    The NFT could have been sold on or burned since, so the log alone is not enough.
const received = await client.getContractEvents({
  address: localAddresses.stakingNFT,
  abi: stakingNFTAbi,
  eventName: "Transfer",
  args: { to: staker },
  fromBlock: 0n,
});
console.log(`\n-- Transfer events received by ${staker} --`);
for (const log of received) {
  const { tokenId } = log.args;
  if (tokenId === undefined) continue;
  console.log(`block ${log.blockNumber}: token #${tokenId} from ${log.args.from}`);

  try {
    const holder = await client.readContract({
      address: localAddresses.stakingNFT,
      abi: stakingNFTAbi,
      functionName: "ownerOf",
      args: [tokenId],
    });
    const claimable = await client.readContract({
      address: localAddresses.stakingApp,
      abi: stakingAppAbi,
      functionName: "claimableRewards",
      args: [tokenId],
    });
    console.log(`   alive, held by ${holder}, claimable ${formatEther(claimable)} ETH`);
  } catch (error) {
    // viem wraps a revert in several error layers; walk() finds the one that carries the decoded custom error.
    const reverted = error instanceof BaseError ? error.walk((e) => e instanceof ContractFunctionRevertedError) : null;
    if (reverted instanceof ContractFunctionRevertedError) {
      console.log(`   gone: reverted with ${reverted.data?.errorName}(${reverted.data?.args?.join(", ")})`);
    } else {
      throw error;
    }
  }
}

// 3. tokenURI is a data URI: a base64 JSON that contains another base64 SVG.
const tokenId = received.at(-1)?.args.tokenId;
if (tokenId !== undefined) {
  const uri = await client.readContract({
    address: localAddresses.stakingNFT,
    abi: stakingNFTAbi,
    functionName: "tokenURI",
    args: [tokenId],
  });
  const metadata = JSON.parse(atob(uri.split(",")[1] ?? ""));
  console.log(`\n-- tokenURI(${tokenId}) --`);
  console.log("name      :", metadata.name);
  console.log("attributes:", JSON.stringify(metadata.attributes));
  console.log("image     :", `${metadata.image.slice(0, 30)}... (${metadata.image.length} chars)`);
}

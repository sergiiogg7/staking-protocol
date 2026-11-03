// Pure-viem write flow: approve -> deposit -> early claim (fails) -> time travel -> claim -> withdraw.
// Every write follows the same three stages the UI will use: simulate, send, wait for the receipt.
// Run with `npm run playground:write` (Anvil must be up: `bash dev.sh`). Net effect on Anvil is a
// claim of 0.01 ETH: the position it opens is closed again at the end.
import {
  BaseError,
  ContractFunctionRevertedError,
  createPublicClient,
  createTestClient,
  createWalletClient,
  formatEther,
  http,
  parseEventLogs,
} from "viem";
import { mnemonicToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingTokenAbi } from "../abi/stakingToken.ts";
import { localAddresses } from "../contracts.ts";

// Anvil's public development mnemonic. Account #2 starts with 100 STK and 10000 ETH.
const account = mnemonicToAccount("test test test test test test test test test test test junk", { addressIndex: 2 });

// pollingInterval: how often waitForTransactionReceipt asks the node; Anvil mines every 2 s.
const publicClient = createPublicClient({ chain: foundry, transport: http(), pollingInterval: 500 });
// The wallet client signs and sends. With a local account viem signs in-process and calls
// eth_sendRawTransaction; with a browser wallet it would delegate to the wallet instead.
const walletClient = createWalletClient({ account, chain: foundry, transport: http() });
// Anvil-only helper to move the node's clock (evm_increaseTime / evm_mine). Not available on real networks.
const testClient = createTestClient({ mode: "anvil", chain: foundry, transport: http() });

const { stakingApp, stakingToken } = localAddresses;

console.log("account:", account.address);
console.log("STK before:", await publicClient.readContract({
  address: stakingToken,
  abi: stakingTokenAbi,
  functionName: "balanceOf",
  args: [account.address],
}));

const amount = await publicClient.readContract({ address: stakingApp, abi: stakingAppAbi, functionName: "fixStakingAmount" });

// 1. approve. simulateContract runs the call as an eth_call first; if it would revert, it throws here
//    and the user never pays gas. It returns a `request` that writeContract can send as is.
console.log("\n-- approve --");
const approval = await publicClient.simulateContract({
  address: stakingToken,
  abi: stakingTokenAbi,
  functionName: "approve",
  args: [stakingApp, amount],
  account,
});
const approveHash = await walletClient.writeContract(approval.request);
console.log("sent     :", approveHash);
// Sending is not confirming: the hash exists as soon as the node accepts the tx, the receipt only once it is mined.
const approveReceipt = await publicClient.waitForTransactionReceipt({ hash: approveHash });
console.log("mined    : block", approveReceipt.blockNumber, "| status", approveReceipt.status, "| gas", approveReceipt.gasUsed);

// 2. deposit. A transaction does not return values, but the simulation does: `result` is the tokenId
//    the node would assign right now. The authoritative tokenId is the one in the event of the real receipt.
console.log("\n-- depositToken --");
const deposit = await publicClient.simulateContract({
  address: stakingApp,
  abi: stakingAppAbi,
  functionName: "depositToken",
  args: [amount],
  account,
});
console.log("simulated tokenId:", deposit.result);
const depositReceipt = await publicClient.waitForTransactionReceipt({ hash: await walletClient.writeContract(deposit.request) });
// A receipt holds raw logs from several contracts; parseEventLogs keeps and decodes the ones in the ABI.
const [deposited] = parseEventLogs({ abi: stakingAppAbi, eventName: "DepositTokens", logs: depositReceipt.logs });
const tokenId = deposited?.args.tokenId_;
if (tokenId === undefined) throw new Error("DepositTokens event not found in the receipt");
console.log("tokenId from the receipt event:", tokenId, "| gas", depositReceipt.gasUsed);

// 3. A claim before the period ends must fail at the simulation stage, with a decoded error.
console.log("\n-- claimRewards too early --");
try {
  await publicClient.simulateContract({ address: stakingApp, abi: stakingAppAbi, functionName: "claimRewards", args: [tokenId], account });
} catch (error) {
  const reverted = error instanceof BaseError ? error.walk((e) => e instanceof ContractFunctionRevertedError) : null;
  if (!(reverted instanceof ContractFunctionRevertedError)) throw error;
  console.log(`reverted: ${reverted.data?.errorName}(${reverted.data?.args?.join(", ")}) seconds remaining`);
}

// 4. Move the node's clock instead of waiting 90 seconds.
console.log("\n-- time travel --");
await testClient.increaseTime({ seconds: 90 });
await testClient.mine({ blocks: 1 });
const claimable = await publicClient.readContract({
  address: stakingApp,
  abi: stakingAppAbi,
  functionName: "claimableRewards",
  args: [tokenId],
});
console.log("claimableRewards:", formatEther(claimable), "ETH");

// 5. claim, reading the amount paid from the RewardsClaimed event.
console.log("\n-- claimRewards --");
const claim = await publicClient.simulateContract({ address: stakingApp, abi: stakingAppAbi, functionName: "claimRewards", args: [tokenId], account });
const claimReceipt = await publicClient.waitForTransactionReceipt({ hash: await walletClient.writeContract(claim.request) });
const [claimed] = parseEventLogs({ abi: stakingAppAbi, eventName: "RewardsClaimed", logs: claimReceipt.logs });
console.log("paid:", formatEther(claimed?.args.amount_ ?? 0n), "ETH | gas", claimReceipt.gasUsed);

// 6. withdraw, which burns the NFT and returns the staked tokens.
console.log("\n-- withdrawTokens --");
const withdraw = await publicClient.simulateContract({ address: stakingApp, abi: stakingAppAbi, functionName: "withdrawTokens", args: [tokenId], account });
const withdrawReceipt = await publicClient.waitForTransactionReceipt({ hash: await walletClient.writeContract(withdraw.request) });
console.log("status:", withdrawReceipt.status, "| gas", withdrawReceipt.gasUsed);
console.log("STK after:", await publicClient.readContract({
  address: stakingToken,
  abi: stakingTokenAbi,
  functionName: "balanceOf",
  args: [account.address],
}));

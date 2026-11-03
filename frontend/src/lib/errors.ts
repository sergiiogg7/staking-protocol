import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
  decodeErrorResult,
  formatUnits,
} from "viem";
import type { Abi, Hex } from "viem";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { stakingTokenAbi } from "../abi/stakingToken.ts";

// StakingApp calls the NFT and the token internally, so a revert can come from any of the three contracts.
// viem only names an error that is in the ABI of the contract being called, so decode against all of them.
const errorsAbi: Abi = [...stakingAppAbi, ...stakingNFTAbi, ...stakingTokenAbi].filter((item) => item.type === "error");

const messages: Record<string, (args: readonly unknown[]) => string> = {
  StakingPeriodNotElapsed: ([remaining]) => `Too early to claim: ${remaining} more seconds until a period completes.`,
  NotPositionOwner: () => "You do not own this position.",
  IncorrectAmount: ([expected]) => `A deposit must be exactly ${formatUnits(expected as bigint, 18)} STK.`,
  EthTransferFailed: () => "The contract does not hold enough ETH to pay this reward. The owner has to fund it first.",
  EnforcedPause: () => "The protocol is paused: deposits and claims are disabled, withdrawals still work.",
  ERC721NonexistentToken: () => "This position no longer exists.",
  ERC20InsufficientBalance: () => "You do not have enough STK for this deposit.",
  ERC20InsufficientAllowance: () => "The contract is not approved to move your STK yet.",
  OwnableUnauthorizedAccount: () => "Only the owner of the contract can do this.",
  PositionsStillOpen: ([open]) => `${open} position(s) are still open. ETH can only be withdrawn when none is open.`,
  ExpectedPause: () => "The protocol is not paused.",
  ZeroAmount: () => "The amount must be greater than zero.",
};

function isHexData(value: unknown): value is Hex {
  return typeof value === "string" && value.startsWith("0x");
}

function decodeData(data: Hex) {
  try {
    const decoded = decodeErrorResult({ abi: errorsAbi, data });
    return { name: decoded.errorName, args: decoded.args ?? [] };
  } catch {
    return undefined;
  }
}

function decodeRevert(reverted: ContractFunctionRevertedError) {
  if (reverted.data) return { name: reverted.data.errorName, args: reverted.data.args ?? [] };
  return reverted.raw ? decodeData(reverted.raw) : undefined;
}

// Turns anything a transaction can throw into one sentence for the user.
export function describeError(error: unknown): string {
  if (error instanceof BaseError) {
    // viem wraps the cause in several layers, so look through them for the one that matters.
    if (error.walk((cause) => cause instanceof UserRejectedRequestError)) return "You rejected the request in your wallet.";

    const reverted = error.walk((cause) => cause instanceof ContractFunctionRevertedError);
    if (reverted instanceof ContractFunctionRevertedError) {
      const decoded = decodeRevert(reverted);
      if (decoded) return messages[decoded.name]?.(decoded.args) ?? `The transaction would fail (${decoded.name}).`;
      return "The transaction would fail.";
    }

    // A plain transaction (such as sending ETH) has no function call, so its revert does not arrive as a
    // ContractFunctionRevertedError: the error bytes sit in `data` of one of the nested causes.
    const withData = error.walk((cause) => isHexData((cause as { data?: unknown }).data));
    if (withData) {
      const decoded = decodeData((withData as unknown as { data: Hex }).data);
      if (decoded) return messages[decoded.name]?.(decoded.args) ?? `The transaction would fail (${decoded.name}).`;
    }
    return error.shortMessage;
  }
  return error instanceof Error ? error.message : "Something went wrong.";
}

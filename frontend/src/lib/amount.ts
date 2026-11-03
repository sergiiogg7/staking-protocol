import { parseEther } from "viem";

// Parses what the user typed as an amount of ETH. Returns undefined when it is not a positive number,
// so the interface can disable the button instead of sending something nonsensical to the wallet.
export function parseEthAmount(text: string): bigint | undefined {
  try {
    const value = parseEther(text.trim());
    return value > 0n ? value : undefined;
  } catch {
    return undefined;
  }
}

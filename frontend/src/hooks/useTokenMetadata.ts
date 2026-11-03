import { useReadContract } from "wagmi";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { localAddresses } from "../contracts.ts";
import { parseTokenUri } from "../lib/tokenUri.ts";

// The metadata of a position NFT, already parsed. `select` runs on the cached string, so the cache holds
// the raw token URI and each component gets the parsed result; a parsing error becomes the query's error.
export function useTokenMetadata(tokenId: bigint) {
  return useReadContract({
    address: localAddresses.stakingNFT,
    abi: stakingNFTAbi,
    functionName: "tokenURI",
    args: [tokenId],
    query: { select: parseTokenUri },
  });
}

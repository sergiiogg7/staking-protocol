import { isAddressEqual } from "viem";
import { useAccount, useBalance, useReadContracts } from "wagmi";
import { stakingAppAbi } from "../abi/stakingApp.ts";
import { stakingNFTAbi } from "../abi/stakingNFT.ts";
import { localAddresses } from "../contracts.ts";

const stakingApp = { address: localAddresses.stakingApp, abi: stakingAppAbi } as const;

// What the admin panel needs to know: who owns the contract, whether it is paused, how many positions are
// open (ETH can only be withdrawn when there are none) and how much ETH the contract holds.
export function useAdminData() {
  const { address } = useAccount();
  const { data, isPending, error } = useReadContracts({
    contracts: [
      { ...stakingApp, functionName: "owner" },
      { ...stakingApp, functionName: "paused" },
      { address: localAddresses.stakingNFT, abi: stakingNFTAbi, functionName: "totalPositions" },
    ],
    allowFailure: false,
  });
  const { data: balance } = useBalance({ address: localAddresses.stakingApp });

  const [owner, paused, openPositions] = data ?? [];
  // Comparing addresses as text would break on letter case; isAddressEqual compares them properly.
  const isOwner = address !== undefined && owner !== undefined && isAddressEqual(address, owner);

  return { owner, paused, openPositions, balance: balance?.value, isOwner, isPending, error };
}

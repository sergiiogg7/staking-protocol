import type { Address } from "viem";

// Addresses of the local deployment (`bash dev.sh` on a fresh Anvil). They are deterministic:
// they derive from the deployer account and its nonce, so every fresh Anvil produces the same ones.
// StakingNFT has no CREATE of its own in the broadcast file: StakingApp creates it in its constructor.
export const localAddresses = {
  stakingToken: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  stakingNFTDescriptor: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  stakingApp: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  stakingNFT: "0x75537828f2ce51be7289709686A69CbFDbB714F1",
} as const satisfies Record<string, Address>;

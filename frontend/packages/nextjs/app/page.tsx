"use client";

import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { DepositCard } from "./_components/DepositCard";
import { PositionCard } from "./_components/PositionCard";

const Home: NextPage = () => {
  const { address } = useAccount();

  const { data: tokenId } = useScaffoldReadContract({
    contractName: "StakingApp",
    functionName: "userTokenId",
    args: [address as `0x${string}`],
    query: { enabled: !!address },
  });

  if (!address) {
    return (
      <main className="flex min-h-[calc(100vh-4rem)] items-center justify-center">
        <div className="text-center space-y-3">
          <h1 className="text-4xl font-bold">STK Staking</h1>
          <p className="text-base-content/50">Connect your wallet to start staking</p>
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-[calc(100vh-4rem)] items-center justify-center p-4">
      {tokenId && tokenId > 0n ? (
        <PositionCard address={address} tokenId={tokenId} />
      ) : (
        <DepositCard address={address} />
      )}
    </main>
  );
};

export default Home;

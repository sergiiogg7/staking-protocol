import { formatEther, formatUnits } from "viem";
import { useAccount, useBalance } from "wagmi";
import { localAddresses } from "../contracts.ts";
import { useMyPositions } from "../hooks/useMyPositions.ts";
import { PositionActions } from "./PositionActions.tsx";
import { PositionImage } from "./PositionImage.tsx";

export function PositionsList() {
  const { isConnected } = useAccount();
  const { data: positions, isPending, error } = useMyPositions();
  // The ETH the contract can pay rewards with: a claim larger than this is bound to fail.
  const { data: contractBalance } = useBalance({ address: localAddresses.stakingApp });

  // Order matters: a query that is disabled (no wallet) also reports isPending, so check the wallet first.
  if (!isConnected) return <p>Connect your wallet to see your positions.</p>;
  if (isPending) return <p>Loading your positions…</p>;
  if (error) return <p className="error">Could not load your positions: {error.message}</p>;
  if (positions.length === 0) return <p>You have no open positions.</p>;

  return (
    <ul className="positions">
      {positions.map((position) => (
        // `key` lets React tell list items apart between renders; the token id is unique and stable.
        <li key={position.tokenId.toString()}>
          <PositionImage tokenId={position.tokenId} />
          <strong>Position #{position.tokenId.toString()}</strong>
          <span>Staked {formatUnits(position.depositAmount, 18)} STK</span>
          <span>Since {new Date(Number(position.depositTimestamp) * 1000).toLocaleString()}</span>
          <span>Claimable {formatEther(position.claimable)} ETH</span>
          <PositionActions position={position} contractBalance={contractBalance?.value} />
        </li>
      ))}
    </ul>
  );
}

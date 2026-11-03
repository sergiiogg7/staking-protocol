import { useTokenMetadata } from "../hooks/useTokenMetadata.ts";

// The image comes from a contract the NFT owner can replace, so it is untrusted. It is only ever shown in an
// <img>: the browser renders an SVG there as a plain picture and never runs scripts inside it. Putting the
// same SVG in the page with dangerouslySetInnerHTML would run them.
export function PositionImage({ tokenId }: { tokenId: bigint }) {
  const { data: metadata, isPending, error } = useTokenMetadata(tokenId);

  if (isPending) return <div className="nft-image" aria-hidden="true" />;
  if (error || !metadata) return <p className="error">Could not load the NFT image.</p>;

  return <img className="nft-image" src={metadata.image} alt={metadata.name} width={120} height={120} />;
}

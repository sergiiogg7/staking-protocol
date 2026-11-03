export interface TokenMetadata {
  name: string;
  description: string;
  image: string;
  attributes: { trait_type: string; value: string | number; display_type?: string }[];
}

const JSON_PREFIX = "data:application/json;base64,";
const IMAGE_PREFIX = "data:image/";

// StakingNFT.tokenURI is a data URI holding base64 JSON, and that JSON holds the image as another data URI.
// The descriptor behind it can be replaced by the NFT owner, so everything in here is untrusted input.
export function parseTokenUri(uri: string): TokenMetadata {
  if (!uri.startsWith(JSON_PREFIX)) throw new Error("Unsupported token URI: expected an on-chain base64 JSON.");

  // atob gives a binary string; decode it as UTF-8 so non-ASCII text survives.
  const bytes = Uint8Array.from(atob(uri.slice(JSON_PREFIX.length)), (char) => char.charCodeAt(0));
  const metadata: unknown = JSON.parse(new TextDecoder().decode(bytes));

  if (typeof metadata !== "object" || metadata === null) throw new Error("The token metadata is not an object.");
  const { name, description, image, attributes } = metadata as Record<string, unknown>;
  if (typeof name !== "string" || typeof image !== "string") throw new Error("The token metadata is incomplete.");

  // Only an image embedded in the metadata is accepted. A remote URL would let whoever controls the
  // descriptor track everyone who opens the page.
  if (!image.startsWith(IMAGE_PREFIX)) throw new Error("The token image is not embedded on-chain.");

  return {
    name,
    description: typeof description === "string" ? description : "",
    image,
    attributes: Array.isArray(attributes) ? attributes : [],
  };
}

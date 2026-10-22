// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ITokenURIDescriptor.sol";

/// @title StakingNFTDescriptor
/// @notice Builds on-chain SVG + JSON metadata for StakingNFT positions.
/// @dev Deployed separately from StakingNFT so the visual design can be updated
///      (by deploying a new descriptor and calling StakingNFT.setDescriptor) without
///      touching the NFT contract or its ownership records. Pattern used by Uniswap v3.
contract StakingNFTDescriptor is ITokenURIDescriptor {
    using Strings for uint256;

    /// @inheritdoc ITokenURIDescriptor
    function constructTokenURI(uint256 tokenId_, uint256 depositAmount_, uint256 depositTimestamp_)
        external
        view
        override
        returns (string memory)
    {
        string memory svg = _buildSVG(tokenId_, depositAmount_, depositTimestamp_);

        // Wrap the SVG in a data URI so it can be embedded in the JSON image field.
        // Base64.encode converts binary bytes to ASCII-safe text; the data: scheme tells
        // browsers how to interpret the inline content without a network request.
        string memory imageUri = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));

        string memory json = string(
            abi.encodePacked(
                '{"name":"Staking Position #',
                tokenId_.toString(),
                '","description":"STK fixed-amount staking position","image":"',
                imageUri,
                '","attributes":[{"trait_type":"Amount","value":"',
                depositAmount_.toString(),
                '"},{"trait_type":"Staked At","value":"',
                depositTimestamp_.toString(),
                '"}]}'
            )
        );

        // Same pattern: encode the full JSON as base64 and prefix with the JSON data URI scheme.
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @dev Builds the SVG markup for a staking position card.
    function _buildSVG(uint256 tokenId_, uint256 depositAmount_, uint256 depositTimestamp_)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">',
                '<rect width="300" height="300" rx="16" fill="#0f172a"/>',
                '<text x="150" y="60" font-family="monospace" font-size="14" fill="#94a3b8" text-anchor="middle">STK Staking Position</text>',
                '<text x="150" y="130" font-family="monospace" font-size="40" font-weight="bold" fill="#f8fafc" text-anchor="middle">#',
                tokenId_.toString(),
                "</text>",
                '<text x="150" y="185" font-family="monospace" font-size="13" fill="#64748b" text-anchor="middle">Amount: ',
                depositAmount_.toString(),
                "</text>",
                '<text x="150" y="215" font-family="monospace" font-size="11" fill="#475569" text-anchor="middle">Since: ',
                depositTimestamp_.toString(),
                "</text>",
                "</svg>"
            )
        );
    }
}

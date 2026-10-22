// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITokenURIDescriptor
/// @notice Interface for contracts that build tokenURI metadata for StakingNFT positions.
/// @dev Declared as `view` (not `pure`) so future implementations can read external state
///      such as price feeds or ENS names without breaking the interface.
interface ITokenURIDescriptor {
    /// @notice Builds the full tokenURI data URI for a staking position.
    /// @param tokenId_ The ERC-721 token ID.
    /// @param depositAmount_ Token amount locked in this position.
    /// @param depositTimestamp_ Unix timestamp at which the position was opened.
    /// @return A base64-encoded JSON data URI containing the position metadata and SVG image.
    function constructTokenURI(uint256 tokenId_, uint256 depositAmount_, uint256 depositTimestamp_)
        external
        view
        returns (string memory);
}

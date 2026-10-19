// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "./ITokenURIDescriptor.sol";

/// @notice Thrown when a caller other than the authorized StakingApp attempts to mint or burn.
/// @param caller The unauthorized address.
error Unauthorized(address caller);

/// @notice Thrown when tokenURI is queried for a token that does not exist.
/// @param tokenId The queried token ID.
error NonexistentToken(uint256 tokenId);

/// @notice Thrown when setDescriptor is called with the zero address.
error InvalidDescriptor();

/// @title StakingNFT
/// @notice ERC-721 receipt for a fixed-amount staking position in StakingApp.
/// @dev Only the StakingApp contract can mint and burn. Metadata is fully on-chain and
///      rendered by an external ITokenURIDescriptor contract so the visual design can be
///      updated without modifying this contract or its ownership records.
///      Token IDs start at 1; 0 is reserved as the "no position" sentinel in StakingApp.
contract StakingNFT is ERC721, Ownable {
    /// @notice The StakingApp contract that is the sole authorized minter and burner.
    address public immutable stakingApp;

    /// @notice Monotonically increasing counter used to assign unique token IDs.
    uint256 private _nextTokenId;

    /// @notice Number of positions currently open (minted but not burned).
    uint256 public totalPositions;

    /// @notice Contract responsible for building tokenURI metadata.
    /// @dev Can be updated by the owner to change the visual design without redeploying StakingNFT.
    ITokenURIDescriptor public descriptor;

    /// @notice Token amount locked in the position represented by each token.
    mapping(uint256 => uint256) public depositAmount;

    /// @notice Unix timestamp at which each position was originally opened.
    mapping(uint256 => uint256) public depositTimestamp;

    /// @notice Emitted when a new staking position NFT is minted.
    event PositionMinted(address indexed to_, uint256 indexed tokenId_);

    /// @notice Emitted when a staking position NFT is burned on withdrawal.
    event PositionBurned(uint256 indexed tokenId_);

    /// @notice Emitted when the owner updates the renderer contract.
    event DescriptorUpdated(address indexed descriptor_);

    modifier onlyStakingApp() {
        if (msg.sender != stakingApp) revert Unauthorized(msg.sender);
        _;
    }

    /// @param name_ ERC-721 collection name shown in wallets.
    /// @param symbol_ ERC-721 collection symbol.
    /// @param stakingApp_ Address of the StakingApp contract authorized to mint and burn.
    /// @param owner_ Address that can update the descriptor.
    /// @param descriptor_ Initial renderer contract.
    constructor(
        string memory name_,
        string memory symbol_,
        address stakingApp_,
        address owner_,
        address descriptor_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        if (descriptor_ == address(0)) revert InvalidDescriptor();
        stakingApp = stakingApp_;
        descriptor = ITokenURIDescriptor(descriptor_);
    }

    /// @notice Replaces the renderer contract. Only callable by the owner.
    /// @param descriptor_ Address of the new ITokenURIDescriptor implementation.
    function setDescriptor(address descriptor_) external onlyOwner {
        if (descriptor_ == address(0)) revert InvalidDescriptor();
        descriptor = ITokenURIDescriptor(descriptor_);
        emit DescriptorUpdated(descriptor_);
    }

    /// @notice Mints a new position NFT. Only callable by StakingApp.
    /// @param to_ Recipient address (the depositor).
    /// @param amount_ Token amount locked in this position.
    /// @param timestamp_ Block timestamp at the moment of deposit.
    /// @return tokenId The newly minted token ID.
    function mint(address to_, uint256 amount_, uint256 timestamp_) external onlyStakingApp returns (uint256) {
        uint256 tokenId = ++_nextTokenId;
        depositAmount[tokenId] = amount_;
        depositTimestamp[tokenId] = timestamp_;
        totalPositions++;
        _mint(to_, tokenId);
        emit PositionMinted(to_, tokenId);
        return tokenId;
    }

    /// @notice Burns a position NFT and clears its metadata. Only callable by StakingApp.
    /// @param tokenId_ The token to burn.
    function burn(uint256 tokenId_) external onlyStakingApp {
        delete depositAmount[tokenId_];
        delete depositTimestamp[tokenId_];
        totalPositions--;
        _burn(tokenId_);
        emit PositionBurned(tokenId_);
    }

    /// @notice Returns the tokenURI by delegating to the descriptor contract.
    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        if (depositTimestamp[tokenId_] == 0) revert NonexistentToken(tokenId_);
        return descriptor.constructTokenURI(tokenId_, depositAmount[tokenId_], depositTimestamp[tokenId_]);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./StakingNFT.sol";

/// @notice Thrown when the deposited amount does not match the required fixed staking amount.
/// @param expected The required fixed staking amount.
/// @param provided The amount the caller attempted to deposit.
error IncorrectAmount(uint256 expected, uint256 provided);

/// @notice Thrown when a caller tries to claim or withdraw a position NFT they do not own.
/// @param tokenId The position the caller attempted to act on.
/// @param caller The address that attempted the call.
error NotPositionOwner(uint256 tokenId, address caller);

/// @notice Thrown when a user tries to claim before the staking period has elapsed.
/// @param remaining Seconds left until the staking period completes.
error StakingPeriodNotElapsed(uint256 remaining);

/// @notice Thrown when the ETH transfer to the staker fails.
error EthTransferFailed();

/// @notice Thrown when a required address argument is the zero address.
error ZeroAddress();

/// @notice Thrown when a required amount argument is zero, or when there is no ETH to withdraw.
error ZeroAmount();

/// @notice Thrown when the owner tries to withdraw ETH while positions that could still claim it are open.
/// @param openPositions Number of positions currently open.
error PositionsStillOpen(uint256 openPositions);

/// @notice Thrown when a staking period falls outside the allowed bounds.
/// @param provided The rejected staking period in seconds.
error InvalidStakingPeriod(uint256 provided);

/// @title StakingApp
/// @notice Fixed-amount ERC20 staking contract that rewards stakers with ETH after each completed period.
///         Each position is an ERC-721 NFT minted on deposit and burned on withdrawal. The NFT is a bearer
///         instrument: whoever owns it can claim its rewards and withdraw its tokens, so a position can be
///         sold or transferred together with its accrued staking time.
/// @dev Inherits Ownable2Step, ReentrancyGuard, and Pausable from OpenZeppelin v5.
///      Only the NFT owner is authorized; an address approved via `approve` or `setApprovalForAll` is not.
contract StakingApp is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Shortest staking period accepted at deployment, in seconds.
    uint256 public constant MIN_STAKING_PERIOD = 1 minutes;

    /// @notice Longest staking period accepted at deployment, in seconds.
    uint256 public constant MAX_STAKING_PERIOD = 365 days;

    /// @notice The ERC20 token accepted for staking.
    IERC20 public immutable stakingToken;

    /// @notice The ERC-721 contract that mints position receipts on deposit.
    StakingNFT public immutable stakingNFT;

    /// @notice Duration in seconds of one staking period; each completed period earns `rewardPerPeriod`.
    /// @dev Immutable on purpose: rewards owed are computed from it, so changing it would rewrite what
    ///      open positions have already accrued.
    uint256 public immutable stakingPeriod;

    /// @notice The exact token amount each user must deposit to participate.
    uint256 public immutable fixStakingAmount;

    /// @notice ETH amount paid to the staker for each completed staking period.
    uint256 public immutable rewardPerPeriod;

    /// @notice Timestamp of the last deposit or successful claim for each position.
    ///         Used to calculate whether the staking period has elapsed. 0 means no open position.
    /// @dev Keyed by token ID rather than by address so the timer travels with the NFT when it is transferred.
    mapping(uint256 => uint256) public lastActivity;

    /// @notice Emitted when a user successfully deposits tokens and receives a position NFT.
    /// @param userAddress_ The address of the depositing user.
    /// @param depositAmount_ The amount of tokens deposited.
    /// @param tokenId_ The ID of the newly minted position NFT.
    event DepositTokens(address indexed userAddress_, uint256 depositAmount_, uint256 indexed tokenId_);

    /// @notice Emitted when a user withdraws their staked tokens and the position NFT is burned.
    /// @param userAddress_ The address of the withdrawing user.
    /// @param withdrawAmount_ The amount of tokens returned.
    /// @param tokenId_ The ID of the burned position NFT.
    event WithdrawTokens(address indexed userAddress_, uint256 withdrawAmount_, uint256 indexed tokenId_);

    /// @notice Emitted when a user successfully claims their ETH reward.
    /// @param user_ The address of the claiming user.
    /// @param amount_ The ETH amount sent to the user: `rewardPerPeriod` times the periods completed.
    event RewardsClaimed(address indexed user_, uint256 amount_);

    /// @notice Emitted when the owner sends ETH to fund the contract.
    /// @param amount_ The ETH amount received.
    event EtherSent(uint256 amount_);

    /// @notice Emitted when the owner recovers the contract's ETH after every position has closed.
    /// @param amount_ The ETH amount sent to the owner.
    event EtherWithdrawn(uint256 amount_);

    /// @notice Deploys the staking contract with the given configuration.
    /// @dev Deploys the StakingNFT itself so it is wired to `address(this)` by construction,
    ///      with no need to predict this contract's address from the deployer's nonce.
    /// @param stakingToken_ Address of the ERC20 token accepted for staking.
    /// @param descriptor_ Address of the ITokenURIDescriptor used to render position metadata.
    /// @param owner_ Address that will own and manage this contract and the StakingNFT it deploys.
    /// @param stakingPeriod_ Duration in seconds of one staking period, within [`MIN_STAKING_PERIOD`, `MAX_STAKING_PERIOD`].
    /// @param fixStakingAmount_ Exact token amount each user must deposit.
    /// @param rewardPerPeriod_ ETH amount paid per completed staking period.
    /// @param nftName_ ERC-721 collection name of the position NFT.
    /// @param nftSymbol_ ERC-721 collection symbol of the position NFT.
    constructor(
        address stakingToken_,
        address descriptor_,
        address owner_,
        uint256 stakingPeriod_,
        uint256 fixStakingAmount_,
        uint256 rewardPerPeriod_,
        string memory nftName_,
        string memory nftSymbol_
    ) Ownable(owner_) {
        if (stakingToken_ == address(0)) revert ZeroAddress();
        if (fixStakingAmount_ == 0 || rewardPerPeriod_ == 0) revert ZeroAmount();
        _validateStakingPeriod(stakingPeriod_);

        stakingToken = IERC20(stakingToken_);
        stakingNFT = new StakingNFT(nftName_, nftSymbol_, address(this), owner_, descriptor_);
        stakingPeriod = stakingPeriod_;
        fixStakingAmount = fixStakingAmount_;
        rewardPerPeriod = rewardPerPeriod_;
    }

    /// @notice Pauses deposits and reward claims. Withdrawals remain available.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, re-enabling deposits and reward claims.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Deposits exactly `fixStakingAmount` tokens and mints an ERC-721 position NFT.
    /// @dev Caller must approve this contract for at least `fixStakingAmount` before calling.
    ///      An address may open any number of positions; each deposit mints a new NFT.
    /// @param tokenAmountToDeposit_ Must equal `fixStakingAmount`; any other value reverts.
    /// @return tokenId The ID of the newly minted position NFT.
    function depositToken(uint256 tokenAmountToDeposit_) external nonReentrant whenNotPaused returns (uint256 tokenId) {
        if (tokenAmountToDeposit_ != fixStakingAmount) revert IncorrectAmount(fixStakingAmount, tokenAmountToDeposit_);

        tokenId = stakingNFT.mint(msg.sender, tokenAmountToDeposit_, block.timestamp);
        lastActivity[tokenId] = block.timestamp;
        stakingToken.safeTransferFrom(msg.sender, address(this), tokenAmountToDeposit_);

        emit DepositTokens(msg.sender, tokenAmountToDeposit_, tokenId);
    }

    /// @notice Withdraws the staked tokens of a position and burns its NFT.
    /// @dev Always available, even when the contract is paused, so users can never be locked in.
    ///      Reverts with {NotPositionOwner} unless the caller owns the NFT.
    ///      Follows the CEI pattern: state is cleared before external calls.
    /// @param tokenId_ The position to close.
    function withdrawTokens(uint256 tokenId_) external nonReentrant {
        _requirePositionOwner(tokenId_);

        delete lastActivity[tokenId_];

        stakingNFT.burn(tokenId_);
        stakingToken.safeTransfer(msg.sender, fixStakingAmount);

        emit WithdrawTokens(msg.sender, fixStakingAmount, tokenId_);
    }

    /// @notice Claims the ETH reward for every staking period a position has completed since its last claim.
    /// @dev Pays `rewardPerPeriod` once per completed period. The timer advances by whole periods only, so the
    ///      time left over after the last completed period keeps counting toward the next one.
    ///      Reverts with {NotPositionOwner} unless the caller owns the NFT, and with {StakingPeriodNotElapsed}
    ///      if not even one period has completed.
    /// @param tokenId_ The position to claim for.
    function claimRewards(uint256 tokenId_) external nonReentrant whenNotPaused {
        _requirePositionOwner(tokenId_);

        uint256 elapsed = block.timestamp - lastActivity[tokenId_];
        if (elapsed < stakingPeriod) revert StakingPeriodNotElapsed(stakingPeriod - elapsed);

        uint256 periods = elapsed / stakingPeriod;
        uint256 reward = periods * rewardPerPeriod;
        lastActivity[tokenId_] += periods * stakingPeriod;

        (bool success,) = msg.sender.call{value: reward}("");
        if (!success) revert EthTransferFailed();

        emit RewardsClaimed(msg.sender, reward);
    }

    /// @notice ETH a position could claim right now.
    /// @dev Returns 0 for a position that does not exist or has not completed a period.
    ///      Computed exactly as {claimRewards} does.
    /// @param tokenId_ The position to query.
    /// @return The ETH amount {claimRewards} would pay for `tokenId_` at this block.
    function claimableRewards(uint256 tokenId_) external view returns (uint256) {
        uint256 lastActivity_ = lastActivity[tokenId_];
        if (lastActivity_ == 0) return 0;
        return ((block.timestamp - lastActivity_) / stakingPeriod) * rewardPerPeriod;
    }

    /// @notice Receives ETH to fund future reward payouts.
    /// @dev Restricted to the owner to prevent accidental ETH sends from third parties.
    receive() external payable onlyOwner {
        emit EtherSent(msg.value);
    }

    /// @notice Sends the contract's whole ETH balance to the owner once no position is open.
    /// @dev Allowed only when `totalPositions` is 0: with no open position nobody can claim, so the ETH is
    ///      surplus and withdrawing it can never reduce what a staker is able to collect. While any position
    ///      is open this reverts with {PositionsStillOpen}. Reverts with {ZeroAmount} if there is no ETH.
    function withdrawEther() external onlyOwner nonReentrant {
        uint256 openPositions = stakingNFT.totalPositions();
        if (openPositions != 0) revert PositionsStillOpen(openPositions);

        uint256 amount = address(this).balance;
        if (amount == 0) revert ZeroAmount();

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert EthTransferFailed();

        emit EtherWithdrawn(amount);
    }

    /// @dev Reverts with {NotPositionOwner} unless `msg.sender` owns `tokenId_`.
    ///      `ownerOf` itself reverts for a nonexistent or burned token.
    function _requirePositionOwner(uint256 tokenId_) private view {
        if (stakingNFT.ownerOf(tokenId_) != msg.sender) revert NotPositionOwner(tokenId_, msg.sender);
    }

    /// @dev Reverts if `stakingPeriod_` is outside the allowed bounds.
    function _validateStakingPeriod(uint256 stakingPeriod_) private pure {
        if (stakingPeriod_ < MIN_STAKING_PERIOD || stakingPeriod_ > MAX_STAKING_PERIOD) {
            revert InvalidStakingPeriod(stakingPeriod_);
        }
    }
}

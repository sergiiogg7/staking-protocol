// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @notice Thrown when the deposited amount does not match the required fixed staking amount.
/// @param expected The required fixed staking amount.
/// @param provided The amount the caller attempted to deposit.
error IncorrectAmount(uint256 expected, uint256 provided);

/// @notice Thrown when a user tries to deposit while already holding an active stake.
error AlreadyDeposited();

/// @notice Thrown when a user tries to withdraw or claim without an active stake.
error NotStaking();

/// @notice Thrown when a user tries to claim before the staking period has elapsed.
/// @param remaining Seconds left until the staking period completes.
error StakingPeriodNotElapsed(uint256 remaining);

/// @notice Thrown when the ETH transfer to the staker fails.
error EthTransferFailed();

/// @title StakingApp
/// @notice Fixed-amount ERC20 staking contract that rewards stakers with ETH after each completed period.
/// @dev Inherits Ownable2Step, ReentrancyGuard, and Pausable from OpenZeppelin v5.
contract StakingApp is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token accepted for staking.
    IERC20 public immutable stakingToken;

    /// @notice Duration in seconds a user must hold their stake before claiming rewards.
    uint256 public stakingPeriod;

    /// @notice The exact token amount each user must deposit to participate.
    uint256 public immutable fixStakingAmount;

    /// @notice ETH amount paid to the staker on each successful reward claim.
    uint256 public immutable rewardPerPeriod;

    /// @notice Token balance currently staked by each user.
    mapping(address => uint256) public userBalance;

    /// @notice Timestamp of the last deposit or successful claim for each user.
    mapping(address => uint256) public elapsePeriod;

    /// @notice Emitted when the owner updates the staking period.
    /// @param stakingPeriod_ The new staking period in seconds.
    event ChangeStakingPeriod(uint256 stakingPeriod_);

    /// @notice Emitted when a user successfully deposits tokens.
    /// @param userAddress_ The address of the depositing user.
    /// @param depositAmount_ The amount of tokens deposited.
    event DepositTokens(address indexed userAddress_, uint256 depositAmount_);

    /// @notice Emitted when a user withdraws their staked tokens.
    /// @param userAddress_ The address of the withdrawing user.
    /// @param withdrawAmount_ The amount of tokens returned.
    event WithdrawTokens(address indexed userAddress_, uint256 withdrawAmount_);

    /// @notice Emitted when a user successfully claims their ETH reward.
    /// @param user_ The address of the claiming user.
    /// @param amount_ The ETH amount sent to the user.
    event RewardsClaimed(address indexed user_, uint256 amount_);

    /// @notice Emitted when the owner sends ETH to fund the contract.
    /// @param amount_ The ETH amount received.
    event EtherSent(uint256 amount_);

    /// @notice Deploys the staking contract with the given configuration.
    /// @param stakingToken_ Address of the ERC20 token accepted for staking.
    /// @param owner_ Address that will own and manage this contract.
    /// @param stakingPeriod_ Duration in seconds required between deposit and reward claim.
    /// @param fixStakingAmount_ Exact token amount each user must deposit.
    /// @param rewardPerPeriod_ ETH amount paid per completed staking period.
    constructor(
        address stakingToken_,
        address owner_,
        uint256 stakingPeriod_,
        uint256 fixStakingAmount_,
        uint256 rewardPerPeriod_
    ) Ownable(owner_) {
        stakingToken = IERC20(stakingToken_);
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

    /// @notice Deposits exactly `fixStakingAmount` tokens into the contract.
    /// @dev Caller must approve this contract for at least `fixStakingAmount` before calling.
    ///      Each address may hold only one active position at a time.
    /// @param tokenAmountToDeposit_ Must equal `fixStakingAmount`; any other value reverts.
    function depositToken(uint256 tokenAmountToDeposit_) external nonReentrant whenNotPaused {
        if (tokenAmountToDeposit_ != fixStakingAmount) revert IncorrectAmount(fixStakingAmount, tokenAmountToDeposit_);
        if (userBalance[msg.sender] != 0) revert AlreadyDeposited();

        stakingToken.safeTransferFrom(msg.sender, address(this), tokenAmountToDeposit_);
        userBalance[msg.sender] += tokenAmountToDeposit_;
        elapsePeriod[msg.sender] = block.timestamp;

        emit DepositTokens(msg.sender, tokenAmountToDeposit_);
    }

    /// @notice Withdraws the caller's staked tokens back to their address.
    /// @dev Always available, even when the contract is paused, so users can never be locked in.
    ///      Follows the CEI pattern: state is cleared before the external transfer.
    function withdrawTokens() external nonReentrant {
        if (userBalance[msg.sender] != fixStakingAmount) revert NotStaking();
        uint256 userBalance_ = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        stakingToken.safeTransfer(msg.sender, userBalance_);

        emit WithdrawTokens(msg.sender, userBalance_);
    }

    /// @notice Claims the ETH reward for the caller's completed staking period.
    /// @dev Resets the staking timestamp on success, so the next period begins immediately
    ///      without requiring a new deposit.
    function claimRewards() external nonReentrant whenNotPaused {
        if (userBalance[msg.sender] != fixStakingAmount) revert NotStaking();

        uint256 elapsePeriod_ = block.timestamp - elapsePeriod[msg.sender];
        if (elapsePeriod_ < stakingPeriod) revert StakingPeriodNotElapsed(stakingPeriod - elapsePeriod_);

        elapsePeriod[msg.sender] = block.timestamp;

        (bool success,) = msg.sender.call{value: rewardPerPeriod}("");
        if (!success) revert EthTransferFailed();

        emit RewardsClaimed(msg.sender, rewardPerPeriod);
    }

    /// @notice Receives ETH to fund future reward payouts.
    /// @dev Restricted to the owner to prevent accidental ETH sends from third parties.
    receive() external payable onlyOwner {
        emit EtherSent(msg.value);
    }

    /// @notice Updates the required staking duration.
    /// @dev Takes effect immediately; users who have already deposited are subject to the new period.
    /// @param stakingPeriod_ New staking period in seconds.
    function changeStakingPeriod(uint256 stakingPeriod_) external onlyOwner {
        stakingPeriod = stakingPeriod_;
        emit ChangeStakingPeriod(stakingPeriod_);
    }
}

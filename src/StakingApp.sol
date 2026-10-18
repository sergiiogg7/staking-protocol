// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

error IncorrectAmount(uint256 expected, uint256 provided);
error AlreadyDeposited();
error NotStaking();
error StakingPeriodNotElapsed(uint256 remaining);
error EthTransferFailed();

contract StakingApp is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;
    uint256 public stakingPeriod;
    uint256 public fixStakingAmount;
    uint256 public rewardPerPeriod;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public elapsePeriod;

    event ChangeStakingPeriod(uint256 stakingPeriod_);
    event DepositTokens(address indexed userAddress_, uint256 depositAmount_);
    event WithdrawTokens(address indexed userAddress_, uint256 withdrawAmount_);
    event RewardsClaimed(address indexed user_, uint256 amount_);
    event EtherSent(uint256 amount_);

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

    function depositToken(uint256 tokenAmountToDeposit_) external nonReentrant {
        if (tokenAmountToDeposit_ != fixStakingAmount) revert IncorrectAmount(fixStakingAmount, tokenAmountToDeposit_);
        if (userBalance[msg.sender] != 0) revert AlreadyDeposited();

        stakingToken.safeTransferFrom(msg.sender, address(this), tokenAmountToDeposit_);
        userBalance[msg.sender] += tokenAmountToDeposit_;
        elapsePeriod[msg.sender] = block.timestamp;

        emit DepositTokens(msg.sender, tokenAmountToDeposit_);
    }

    function withdrawTokens() external nonReentrant {
        // CEI PATTERN

        // Check
        if (userBalance[msg.sender] != fixStakingAmount) revert NotStaking();
        // Effects
        uint256 userBalance_ = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        // Interaction
        stakingToken.safeTransfer(msg.sender, userBalance_);

        emit WithdrawTokens(msg.sender, userBalance_);
    }

    function claimRewards() external nonReentrant {
        //1. Check State
        if (userBalance[msg.sender] != fixStakingAmount) revert NotStaking();

        //2. Calculate reward amount
        uint256 elapsePeriod_ = block.timestamp - elapsePeriod[msg.sender];
        if (elapsePeriod_ < stakingPeriod) revert StakingPeriodNotElapsed(stakingPeriod - elapsePeriod_);

        //3. Update State
        elapsePeriod[msg.sender] = block.timestamp;

        //4. Transfer Rewards
        (bool success,) = msg.sender.call{value: rewardPerPeriod}("");
        if (!success) revert EthTransferFailed();

        emit RewardsClaimed(msg.sender, rewardPerPeriod);
    }

    receive() external payable onlyOwner {
        emit EtherSent(msg.value);
    }

    function changeStakingPeriod(uint256 stakingPeriod_) external onlyOwner {
        stakingPeriod = stakingPeriod_;
        emit ChangeStakingPeriod(stakingPeriod_);
    }
}

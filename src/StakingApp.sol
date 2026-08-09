// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingApp is Ownable {
    address public stakingToken;
    uint256 public stakingPeriod;
    uint256 public fixStakingAmount;
    uint256 public rewardPerPeriod;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public elapsePeriod;

    event ChangeStakingPeriod(uint256 stakingPeriod_);
    event DepositTokens(address userAddress_, uint256 depositAmount_);
    event WithdrawTokens(address userAddress_, uint256 withdrawAmount_);
    event EtherSent(uint256 amount_);

    constructor(
        address stakingToken_,
        address owner_,
        uint256 stakingPeriod_,
        uint256 fixStakingAmount_,
        uint256 rewardPerPeriod_
    ) Ownable(owner_) {
        stakingToken = stakingToken_;
        stakingPeriod = stakingPeriod_;
        fixStakingAmount = fixStakingAmount_;
        rewardPerPeriod = rewardPerPeriod_;
    }

    function depositToken(uint256 tokenAmountToDeposit_) external {
        require(tokenAmountToDeposit_ == fixStakingAmount, "Incorrect Amount");
        require(userBalance[msg.sender] == 0, "User already deposited");

        IERC20(stakingToken).transferFrom(msg.sender, address(this), tokenAmountToDeposit_);
        userBalance[msg.sender] += tokenAmountToDeposit_;
        elapsePeriod[msg.sender] = block.timestamp;

        emit DepositTokens(msg.sender, tokenAmountToDeposit_);
    }

    function withdrawTokens() external {
        // CEI PATTERN

        // Check
        require(userBalance[msg.sender] == fixStakingAmount, "Not staking");
        // Effects
        uint256 userBalance_ = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        // Interaction
        IERC20(stakingToken).transfer(msg.sender, userBalance_);

        emit WithdrawTokens(msg.sender, userBalance_);
    }

    function claimRewards() external {
        //1. Check State
        require(userBalance[msg.sender] == fixStakingAmount, "Not staking");

        //2. Calculate reward amount
        uint256 elapsePeriod_ = block.timestamp - elapsePeriod[msg.sender];
        require(elapsePeriod_ >= stakingPeriod, "Need to wait");

        //3. Update State
        elapsePeriod[msg.sender] = block.timestamp;

        //4. Transfer Rewards
        (bool success,) = msg.sender.call{value: rewardPerPeriod}("");
        require(success, "Transfer failed");
    }

    receive() external payable onlyOwner {
        emit EtherSent(msg.value);
    }

    function changeStakingPeriod(uint256 stakingPeriod_) external onlyOwner {
        stakingPeriod = stakingPeriod_;
        emit ChangeStakingPeriod(stakingPeriod_);
    }
}

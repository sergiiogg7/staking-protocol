// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingApp.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingTokenTest is Test {
    StakingToken stakingToken;
    StakingApp stakingApp;

    string name_ = "Staking Token";
    string symbol_ = "STK";

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    address newOwner = vm.addr(5);
    uint256 stakingPeriod_ = 100000000000000;
    uint256 fixedStakingAmount_ = 10;
    uint256 rewardPerPeriod_ = 1 ether;

    function setUp() external {
        stakingToken = new StakingToken(name_, symbol_, owner_);
        stakingApp =
            new StakingApp(address(stakingToken), owner_, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_);
    }

    function _fundUser(address user_, uint256 amount_) internal {
        vm.startPrank(owner_);
        stakingToken.mint(amount_);
        assertTrue(stakingToken.transfer(user_, amount_));
        vm.stopPrank();
    }

    function testChangeStakingPeriodShouldRevertIfNotOwner() external {
        uint256 newStakingPeriod_ = 1;

        vm.expectRevert();
        stakingApp.changeStakingPeriod(newStakingPeriod_);
    }

    function testShouldChangeStakingPeriod() external {
        vm.startPrank(owner_);
        uint256 newStakingPeriod_ = 1;

        uint256 stakingPeriodBefore_ = stakingApp.stakingPeriod(); // ? not getterts or setters?
        stakingApp.changeStakingPeriod(newStakingPeriod_);
        uint256 stakingPeriodAfter_ = stakingApp.stakingPeriod();

        assert(stakingPeriodBefore_ != stakingPeriodAfter_);
        assert(stakingPeriodAfter_ == newStakingPeriod_);

        vm.stopPrank();
    }

    function testContractReceiveEtherCorrectly() external {
        vm.startPrank(owner_);
        uint256 etherValue = 1 ether;
        vm.deal(owner_, etherValue);

        uint256 balanceBefore = address(stakingApp).balance;
        (bool success,) = address(stakingApp).call{value: etherValue}("");
        require(success, "Transfer failed");
        uint256 balanceAfter = address(stakingApp).balance;

        assert(balanceAfter - balanceBefore == etherValue);
        vm.stopPrank();
    }

    function testIncorrectAmountShouldRevert() external {
        vm.startPrank(randomUser);
        uint256 depositAmount = 1;
        vm.expectRevert("Incorrect Amount");
        stakingApp.depositToken(depositAmount);
        vm.stopPrank();
    }

    function testDepositTokensCorrectly() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);

        vm.stopPrank();
    }

    function testUserCanNotDepositMoreThanOnce() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);
        vm.stopPrank();

        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        vm.expectRevert("User already deposited");
        stakingApp.depositToken(tokenAmount);

        vm.stopPrank();
    }

    function testCanNotWithdrawIfNotStaking() external {
        vm.startPrank(randomUser);

        vm.expectRevert("Not staking");
        stakingApp.withdrawTokens();

        vm.stopPrank();
    }

    function testCanWithdrawAfterDeposit() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);

        uint256 userBalanceBefore2 = IERC20(stakingToken).balanceOf(randomUser);
        uint256 userBalanceInMapping = stakingApp.userBalance(randomUser);
        stakingApp.withdrawTokens();
        uint256 userBalanceAfter2 = IERC20(stakingToken).balanceOf(randomUser);

        assert(userBalanceAfter2 == userBalanceBefore2 + userBalanceInMapping);

        vm.stopPrank();
    }

    function testCanNotClaimIfNotStaking() external {
        vm.startPrank(randomUser);

        vm.expectRevert("Not staking");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testCanNotClaimIfNotElapsedTime() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);

        vm.expectRevert("Need to wait");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testShouldRevertIfNoEther() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);

        vm.warp(block.timestamp + stakingPeriod_);
        vm.expectRevert("Transfer failed");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testCanClaimRewardsCorrectly() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        uint256 userBalanceBefore = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodBefore = stakingApp.elapsePeriod(randomUser);
        IERC20(stakingToken).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        uint256 userBalanceAfter = stakingApp.userBalance(randomUser);
        uint256 elapsePeriodAfter = stakingApp.elapsePeriod(randomUser);

        assert(userBalanceAfter - userBalanceBefore == tokenAmount);
        assert(elapsePeriodBefore == 0);
        assert(elapsePeriodAfter == block.timestamp);
        vm.stopPrank();

        vm.startPrank(owner_);
        uint256 etherAmount = 100000 ether;
        vm.deal(owner_, etherAmount);
        (bool success,) = address(stakingApp).call{value: etherAmount}("");
        require(success, "Test transfer failed");
        vm.stopPrank();

        vm.startPrank(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);
        uint256 etherAmountBefore = address(randomUser).balance;
        stakingApp.claimRewards();
        uint256 etherAmountAfter = address(randomUser).balance;
        uint256 elapsedPeriod = stakingApp.elapsePeriod(randomUser);

        assert(etherAmountAfter - etherAmountBefore == rewardPerPeriod_);
        assert(elapsedPeriod == block.timestamp);

        vm.stopPrank();
    }

    function testTransferOwnershipRequiresTwoSteps() external {
        vm.startPrank(owner_);
        stakingApp.transferOwnership(newOwner);
        vm.stopPrank();

        assert(stakingApp.owner() == owner_);
        assert(stakingApp.pendingOwner() == newOwner);
    }

    function testAcceptOwnershipTransfersOwnership() external {
        vm.startPrank(owner_);
        stakingApp.transferOwnership(newOwner);
        vm.stopPrank();

        vm.prank(newOwner);
        stakingApp.acceptOwnership();

        assert(stakingApp.owner() == newOwner);
        assert(stakingApp.pendingOwner() == address(0));
    }

    function testAcceptOwnershipShouldRevertIfNotPendingOwner() external {
        vm.startPrank(owner_);
        stakingApp.transferOwnership(newOwner);
        vm.stopPrank();

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.acceptOwnership();
    }

    function testTransferOwnershipShouldRevertIfNotOwner() external {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.transferOwnership(newOwner);
    }
}

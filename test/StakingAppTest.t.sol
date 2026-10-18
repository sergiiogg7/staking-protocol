// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingApp.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {
    IncorrectAmount,
    AlreadyDeposited,
    NotStaking,
    StakingPeriodNotElapsed,
    EthTransferFailed
} from "../src/StakingApp.sol";

contract StakingAppTest is Test {
    StakingToken stakingToken;
    StakingApp stakingApp;

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    address newOwner = vm.addr(5);
    uint256 stakingPeriod_ = 100_000_000_000_000;
    uint256 fixedStakingAmount_ = 10;
    uint256 rewardPerPeriod_ = 1 ether;

    function setUp() external {
        stakingToken = new StakingToken("Staking Token", "STK", owner_);
        stakingApp =
            new StakingApp(address(stakingToken), owner_, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _fundUser(address user_, uint256 amount_) internal {
        vm.startPrank(owner_);
        stakingToken.mint(amount_);
        assertTrue(stakingToken.transfer(user_, amount_));
        vm.stopPrank();
    }

    function _stakeAs(address user_) internal {
        uint256 amount = stakingApp.fixStakingAmount();
        _fundUser(user_, amount);
        vm.startPrank(user_);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount);
        stakingApp.depositToken(amount);
        vm.stopPrank();
    }

    function _fundContractWithEth() internal {
        vm.startPrank(owner_);
        vm.deal(owner_, 100_000 ether);
        (bool success,) = address(stakingApp).call{value: 100_000 ether}("");
        require(success, "ETH fund failed");
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // changeStakingPeriod
    // -------------------------------------------------------------------------

    function testChangeStakingPeriodShouldRevertIfNotOwner() external {
        vm.expectRevert();
        stakingApp.changeStakingPeriod(1);
    }

    function testShouldChangeStakingPeriod() external {
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(1);

        assertEq(stakingApp.stakingPeriod(), 1);
    }

    // -------------------------------------------------------------------------
    // receive
    // -------------------------------------------------------------------------

    function testContractReceiveEtherCorrectly() external {
        uint256 balanceBefore = address(stakingApp).balance;
        _fundContractWithEth();

        assertEq(address(stakingApp).balance - balanceBefore, 100_000 ether);
    }

    // -------------------------------------------------------------------------
    // depositToken
    // -------------------------------------------------------------------------

    function testIncorrectAmountShouldRevert() external {
        uint256 depositAmount = 1;
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(IncorrectAmount.selector, fixedStakingAmount_, depositAmount));
        stakingApp.depositToken(depositAmount);
    }

    function testDepositTokensCorrectly() external {
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        vm.stopPrank();

        assertEq(stakingApp.userBalance(randomUser), tokenAmount);
        assertEq(stakingApp.elapsePeriod(randomUser), block.timestamp);
    }

    function testUserCanNotDepositMoreThanOnce() external {
        _stakeAs(randomUser);
        _fundUser(randomUser, fixedStakingAmount_);

        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        vm.expectRevert(AlreadyDeposited.selector);
        stakingApp.depositToken(fixedStakingAmount_);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // withdrawTokens
    // -------------------------------------------------------------------------

    function testCanNotWithdrawIfNotStaking() external {
        vm.prank(randomUser);
        vm.expectRevert(NotStaking.selector);
        stakingApp.withdrawTokens();
    }

    function testCanWithdrawAfterDeposit() external {
        _stakeAs(randomUser);

        uint256 tokenBalanceBefore = IERC20(address(stakingToken)).balanceOf(randomUser);
        uint256 stakedAmount = stakingApp.userBalance(randomUser);

        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        assertEq(IERC20(address(stakingToken)).balanceOf(randomUser), tokenBalanceBefore + stakedAmount);
        assertEq(stakingApp.userBalance(randomUser), 0);
    }

    // -------------------------------------------------------------------------
    // claimRewards
    // -------------------------------------------------------------------------

    function testCanNotClaimIfNotStaking() external {
        vm.prank(randomUser);
        vm.expectRevert(NotStaking.selector);
        stakingApp.claimRewards();
    }

    function testCanNotClaimIfNotElapsedTime() external {
        _stakeAs(randomUser);

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(StakingPeriodNotElapsed.selector, stakingPeriod_));
        stakingApp.claimRewards();
    }

    function testShouldRevertIfNoEther() external {
        _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);

        vm.prank(randomUser);
        vm.expectRevert(EthTransferFailed.selector);
        stakingApp.claimRewards();
    }

    function testCanClaimRewardsCorrectly() external {
        _stakeAs(randomUser);
        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);

        uint256 ethBefore = address(randomUser).balance;
        vm.startPrank(randomUser);
        vm.expectEmit(true, false, false, true);
        emit StakingApp.RewardsClaimed(randomUser, rewardPerPeriod_);
        stakingApp.claimRewards();
        vm.stopPrank();

        assertEq(address(randomUser).balance - ethBefore, rewardPerPeriod_);
        assertEq(stakingApp.elapsePeriod(randomUser), block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Ownership
    // -------------------------------------------------------------------------

    function testTransferOwnershipRequiresTwoSteps() external {
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        assertEq(stakingApp.owner(), owner_);
        assertEq(stakingApp.pendingOwner(), newOwner);
    }

    function testAcceptOwnershipTransfersOwnership() external {
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        vm.prank(newOwner);
        stakingApp.acceptOwnership();

        assertEq(stakingApp.owner(), newOwner);
        assertEq(stakingApp.pendingOwner(), address(0));
    }

    function testAcceptOwnershipShouldRevertIfNotPendingOwner() external {
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.acceptOwnership();
    }

    function testTransferOwnershipShouldRevertIfNotOwner() external {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.transferOwnership(newOwner);
    }

    // -------------------------------------------------------------------------
    // Security
    // -------------------------------------------------------------------------

    function testClaimRewardsShouldRevertOnReentrancy() external {
        ReentrantAttacker attacker = new ReentrantAttacker(payable(address(stakingApp)));

        _fundUser(address(attacker), fixedStakingAmount_);
        vm.startPrank(address(attacker));
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        attacker.deposit(fixedStakingAmount_);
        vm.stopPrank();

        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);

        vm.prank(address(attacker));
        attacker.claim();

        assertEq(attacker.lastRevertReason(), abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
    }

    // -------------------------------------------------------------------------
    // Pausable
    // -------------------------------------------------------------------------

    function testDepositRevertsWhenPaused() external {
        vm.prank(owner_);
        stakingApp.pause();

        _fundUser(randomUser, fixedStakingAmount_);
        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingApp.depositToken(fixedStakingAmount_);
        vm.stopPrank();
    }

    function testClaimRevertsWhenPaused() external {
        _stakeAs(randomUser);

        vm.prank(owner_);
        stakingApp.pause();

        vm.warp(block.timestamp + stakingPeriod_);
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingApp.claimRewards();
    }

    function testWithdrawSucceedsWhenPaused() external {
        _stakeAs(randomUser);

        vm.prank(owner_);
        stakingApp.pause();

        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        assertEq(stakingApp.userBalance(randomUser), 0);
    }
}

contract ReentrantAttacker {
    StakingApp public stakingApp;
    bytes public lastRevertReason;

    constructor(address payable stakingApp_) {
        stakingApp = StakingApp(stakingApp_);
    }

    function deposit(uint256 amount_) external {
        stakingApp.depositToken(amount_);
    }

    function claim() external {
        stakingApp.claimRewards();
    }

    receive() external payable {
        (bool success, bytes memory data) = address(stakingApp).call(abi.encodeWithSignature("claimRewards()"));
        if (!success) {
            lastRevertReason = data;
        }
    }
}

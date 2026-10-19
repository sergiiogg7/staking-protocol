// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {
    IncorrectAmount,
    AlreadyDeposited,
    NotStaking,
    StakingPeriodNotElapsed,
    EthTransferFailed
} from "../src/StakingApp.sol";
import {Unauthorized} from "../src/StakingNFT.sol";

contract StakingAppTest is Test {
    StakingToken stakingToken;
    StakingNFTDescriptor descriptor;
    StakingNFT stakingNFT;
    StakingApp stakingApp;

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    address newOwner = vm.addr(5);
    uint256 stakingPeriod_ = 100_000_000_000_000;
    uint256 fixedStakingAmount_ = 10;
    uint256 rewardPerPeriod_ = 1 ether;

    function setUp() external {
        // Deploy order: token(nonce+0), descriptor(nonce+1), nft(nonce+2), app(nonce+3).
        uint64 nonce = vm.getNonce(address(this));
        address predictedStakingApp = vm.computeCreateAddress(address(this), nonce + 3);

        stakingToken = new StakingToken("Staking Token", "STK", owner_);
        descriptor = new StakingNFTDescriptor();
        stakingNFT = new StakingNFT("STK Position", "STKP", predictedStakingApp, owner_, address(descriptor));
        stakingApp = new StakingApp(
            address(stakingToken), address(stakingNFT), owner_, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_
        );
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

    function test_changeStakingPeriod_byNonOwner_reverts() external {
        // Arrange / Act / Assert
        vm.expectRevert();
        vm.prank(randomUser);
        stakingApp.changeStakingPeriod(1);
    }

    function test_changeStakingPeriod_byOwner_updatesValue() external {
        // Arrange
        uint256 newPeriod = 1;

        // Act
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(newPeriod);

        // Assert
        assertEq(stakingApp.stakingPeriod(), newPeriod);
    }

    // -------------------------------------------------------------------------
    // receive
    // -------------------------------------------------------------------------

    function test_receive_byOwner_acceptsEther() external {
        // Arrange
        uint256 balanceBefore = address(stakingApp).balance;

        // Act
        _fundContractWithEth();

        // Assert
        assertEq(address(stakingApp).balance - balanceBefore, 100_000 ether);
    }

    // -------------------------------------------------------------------------
    // depositToken
    // -------------------------------------------------------------------------

    function test_depositToken_withWrongAmount_revertsWithIncorrectAmount() external {
        // Arrange
        uint256 depositAmount = 1;

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(IncorrectAmount.selector, fixedStakingAmount_, depositAmount));
        stakingApp.depositToken(depositAmount);
    }

    function test_depositToken_whenValid_mintsNFTAndSetsState() external {
        // Arrange
        uint256 tokenAmount = stakingApp.fixStakingAmount();
        _fundUser(randomUser, tokenAmount);

        // Act
        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), tokenAmount);
        stakingApp.depositToken(tokenAmount);
        vm.stopPrank();

        // Assert
        uint256 tokenId = stakingApp.userTokenId(randomUser);
        assertGt(tokenId, 0);
        assertEq(stakingNFT.ownerOf(tokenId), randomUser);
        assertEq(stakingApp.lastActivity(randomUser), block.timestamp);
    }

    function test_depositToken_whenAlreadyDeposited_revertsWithAlreadyDeposited() external {
        // Arrange
        _stakeAs(randomUser);
        _fundUser(randomUser, fixedStakingAmount_);

        // Act / Assert
        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        vm.expectRevert(AlreadyDeposited.selector);
        stakingApp.depositToken(fixedStakingAmount_);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // withdrawTokens
    // -------------------------------------------------------------------------

    function test_withdrawTokens_whenNotStaking_revertsWithNotStaking() external {
        // Arrange / Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(NotStaking.selector);
        stakingApp.withdrawTokens();
    }

    function test_withdrawTokens_afterDeposit_returnsTokensAndBurnsNFT() external {
        // Arrange
        _stakeAs(randomUser);
        uint256 tokenBalanceBefore = IERC20(address(stakingToken)).balanceOf(randomUser);

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        // Assert
        assertEq(IERC20(address(stakingToken)).balanceOf(randomUser), tokenBalanceBefore + fixedStakingAmount_);
        assertEq(stakingApp.userTokenId(randomUser), 0);
        assertEq(stakingNFT.totalPositions(), 0);
    }

    // -------------------------------------------------------------------------
    // claimRewards
    // -------------------------------------------------------------------------

    function test_claimRewards_whenNotStaking_revertsWithNotStaking() external {
        // Arrange / Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(NotStaking.selector);
        stakingApp.claimRewards();
    }

    function test_claimRewards_beforePeriodElapses_revertsWithStakingPeriodNotElapsed() external {
        // Arrange
        _stakeAs(randomUser);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(StakingPeriodNotElapsed.selector, stakingPeriod_));
        stakingApp.claimRewards();
    }

    function test_claimRewards_withNoEther_revertsWithEthTransferFailed() external {
        // Arrange
        _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(EthTransferFailed.selector);
        stakingApp.claimRewards();
    }

    function test_claimRewards_afterPeriodElapses_transfersRewardAndResetsTimer() external {
        // Arrange
        _stakeAs(randomUser);
        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);
        uint256 ethBefore = address(randomUser).balance;

        // Act
        vm.startPrank(randomUser);
        vm.expectEmit(true, false, false, true);
        emit StakingApp.RewardsClaimed(randomUser, rewardPerPeriod_);
        stakingApp.claimRewards();
        vm.stopPrank();

        // Assert
        assertEq(address(randomUser).balance - ethBefore, rewardPerPeriod_);
        assertEq(stakingApp.lastActivity(randomUser), block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Ownership
    // -------------------------------------------------------------------------

    function test_transferOwnership_byOwner_setsPendingOwner() external {
        // Act
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        // Assert
        assertEq(stakingApp.owner(), owner_);
        assertEq(stakingApp.pendingOwner(), newOwner);
    }

    function test_acceptOwnership_byPendingOwner_transfersOwnership() external {
        // Arrange
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        // Act
        vm.prank(newOwner);
        stakingApp.acceptOwnership();

        // Assert
        assertEq(stakingApp.owner(), newOwner);
        assertEq(stakingApp.pendingOwner(), address(0));
    }

    function test_acceptOwnership_byNonPendingOwner_reverts() external {
        // Arrange
        vm.prank(owner_);
        stakingApp.transferOwnership(newOwner);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.acceptOwnership();
    }

    function test_transferOwnership_byNonOwner_reverts() external {
        // Arrange / Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.transferOwnership(newOwner);
    }

    // -------------------------------------------------------------------------
    // Security
    // -------------------------------------------------------------------------

    function test_claimRewards_onReentrantCall_blocksWithGuard() external {
        // Arrange
        ReentrantAttacker attacker = new ReentrantAttacker(payable(address(stakingApp)));

        _fundUser(address(attacker), fixedStakingAmount_);
        vm.startPrank(address(attacker));
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        attacker.deposit(fixedStakingAmount_);
        vm.stopPrank();

        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);

        // Act
        vm.prank(address(attacker));
        attacker.claim();

        // Assert
        assertEq(attacker.lastRevertReason(), abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
    }

    // -------------------------------------------------------------------------
    // Pausable
    // -------------------------------------------------------------------------

    function test_depositToken_whenPaused_revertsWithEnforcedPause() external {
        // Arrange
        vm.prank(owner_);
        stakingApp.pause();
        _fundUser(randomUser, fixedStakingAmount_);

        // Act / Assert
        vm.startPrank(randomUser);
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingApp.depositToken(fixedStakingAmount_);
        vm.stopPrank();
    }

    function test_claimRewards_whenPaused_revertsWithEnforcedPause() external {
        // Arrange
        _stakeAs(randomUser);
        vm.prank(owner_);
        stakingApp.pause();
        vm.warp(block.timestamp + stakingPeriod_);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingApp.claimRewards();
    }

    function test_withdrawTokens_whenPaused_succeeds() external {
        // Arrange
        _stakeAs(randomUser);
        vm.prank(owner_);
        stakingApp.pause();

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        // Assert
        assertEq(stakingApp.userTokenId(randomUser), 0);
    }

    function test_unpause_afterPause_restoresDeposit() external {
        // Arrange
        vm.startPrank(owner_);
        stakingApp.pause();
        stakingApp.unpause();
        vm.stopPrank();

        // Act
        _stakeAs(randomUser);

        // Assert
        assertGt(stakingApp.userTokenId(randomUser), 0);
    }

    function test_unpause_byNonOwner_reverts() external {
        // Arrange
        vm.prank(owner_);
        stakingApp.pause();

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        stakingApp.unpause();
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

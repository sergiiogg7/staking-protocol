// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IncorrectAmount, NotPositionOwner, StakingPeriodNotElapsed, EthTransferFailed} from "../src/StakingApp.sol";
import {Unauthorized, InvalidDescriptor} from "../src/StakingNFT.sol";

contract StakingAppTest is Test {
    StakingToken stakingToken;
    StakingNFTDescriptor descriptor;
    StakingNFT stakingNFT;
    StakingApp stakingApp;

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    address newOwner = vm.addr(5);
    address otherUser = vm.addr(6);
    uint256 stakingPeriod_ = 30 days;
    uint256 fixedStakingAmount_ = 10;
    uint256 rewardPerPeriod_ = 1 ether;

    function setUp() external {
        stakingToken = new StakingToken("Staking Token", "STK", owner_);
        descriptor = new StakingNFTDescriptor();
        stakingApp = new StakingApp(
            address(stakingToken),
            address(descriptor),
            owner_,
            stakingPeriod_,
            fixedStakingAmount_,
            rewardPerPeriod_,
            "STK Position",
            "STKP"
        );
        stakingNFT = stakingApp.stakingNFT();
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _deployApp(address token_, address descriptor_, uint256 period_, uint256 fixedAmount_, uint256 reward_)
        internal
        returns (StakingApp)
    {
        return new StakingApp(token_, descriptor_, owner_, period_, fixedAmount_, reward_, "STK Position", "STKP");
    }

    function _fundUser(address user_, uint256 amount_) internal {
        vm.startPrank(owner_);
        stakingToken.mint(amount_);
        assertTrue(stakingToken.transfer(user_, amount_));
        vm.stopPrank();
    }

    function _stakeAs(address user_) internal returns (uint256 tokenId_) {
        uint256 amount = stakingApp.fixStakingAmount();
        _fundUser(user_, amount);
        vm.startPrank(user_);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount);
        tokenId_ = stakingApp.depositToken(amount);
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
        stakingApp.changeStakingPeriod(1 days);
    }

    function test_changeStakingPeriod_byOwner_updatesValue() external {
        // Arrange
        uint256 newPeriod = 1 days;

        // Act
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(newPeriod);

        // Assert
        assertEq(stakingApp.stakingPeriod(), newPeriod);
    }

    function test_changeStakingPeriod_belowMin_revertsWithInvalidStakingPeriod() external {
        // Arrange
        uint256 tooShort = stakingApp.MIN_STAKING_PERIOD() - 1;

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(InvalidStakingPeriod.selector, tooShort));
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(tooShort);
    }

    function test_changeStakingPeriod_aboveMax_revertsWithInvalidStakingPeriod() external {
        // Arrange
        uint256 tooLong = stakingApp.MAX_STAKING_PERIOD() + 1;

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(InvalidStakingPeriod.selector, tooLong));
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(tooLong);
    }

    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------

    function test_constructor_withZeroStakingToken_revertsWithZeroAddress() external {
        // Arrange / Act / Assert
        vm.expectRevert(ZeroAddress.selector);
        _deployApp(address(0), address(descriptor), stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_);
    }

    function test_constructor_withZeroDescriptor_revertsWithInvalidDescriptor() external {
        // Arrange / Act / Assert
        vm.expectRevert(InvalidDescriptor.selector);
        _deployApp(address(stakingToken), address(0), stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_);
    }

    function test_constructor_withZeroFixStakingAmount_revertsWithZeroAmount() external {
        // Arrange / Act / Assert
        vm.expectRevert(ZeroAmount.selector);
        _deployApp(address(stakingToken), address(descriptor), stakingPeriod_, 0, rewardPerPeriod_);
    }

    function test_constructor_withZeroReward_revertsWithZeroAmount() external {
        // Arrange / Act / Assert
        vm.expectRevert(ZeroAmount.selector);
        _deployApp(address(stakingToken), address(descriptor), stakingPeriod_, fixedStakingAmount_, 0);
    }

    function test_constructor_withInvalidPeriod_revertsWithInvalidStakingPeriod() external {
        // Arrange
        uint256 invalid = 0;

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(InvalidStakingPeriod.selector, invalid));
        _deployApp(address(stakingToken), address(descriptor), invalid, fixedStakingAmount_, rewardPerPeriod_);
    }

    function test_constructor_deploysNftWiredToApp() external view {
        // Assert
        assertEq(stakingNFT.stakingApp(), address(stakingApp));
        assertEq(stakingNFT.owner(), owner_);
        assertEq(address(stakingNFT.descriptor()), address(descriptor));
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
        uint256 tokenId = stakingApp.depositToken(tokenAmount);
        vm.stopPrank();

        // Assert
        assertGt(tokenId, 0);
        assertEq(stakingNFT.ownerOf(tokenId), randomUser);
        assertEq(stakingApp.lastActivity(tokenId), block.timestamp);
    }

    function test_depositToken_twiceBySameAddress_mintsTwoIndependentPositions() external {
        // Arrange
        uint256 firstTokenId = _stakeAs(randomUser);

        // Act
        uint256 secondTokenId = _stakeAs(randomUser);

        // Assert
        assertEq(secondTokenId, firstTokenId + 1);
        assertEq(stakingNFT.balanceOf(randomUser), 2);
        assertEq(stakingNFT.totalPositions(), 2);
    }

    // -------------------------------------------------------------------------
    // withdrawTokens
    // -------------------------------------------------------------------------

    function test_withdrawTokens_byNonOwner_revertsWithNotPositionOwner() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);

        // Act / Assert
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, tokenId, otherUser));
        stakingApp.withdrawTokens(tokenId);
    }

    function test_withdrawTokens_forNonexistentToken_revertsWithERC721NonexistentToken() external {
        // Arrange
        uint256 nonexistentTokenId = 999;

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", nonexistentTokenId));
        stakingApp.withdrawTokens(nonexistentTokenId);
    }

    function test_withdrawTokens_afterDeposit_returnsTokensAndBurnsNFT() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        uint256 tokenBalanceBefore = IERC20(address(stakingToken)).balanceOf(randomUser);

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens(tokenId);

        // Assert
        assertEq(IERC20(address(stakingToken)).balanceOf(randomUser), tokenBalanceBefore + fixedStakingAmount_);
        assertEq(stakingApp.lastActivity(tokenId), 0);
        assertEq(stakingNFT.totalPositions(), 0);
    }

    function test_withdrawTokens_afterWithdraw_cannotBeRepeated() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.prank(randomUser);
        stakingApp.withdrawTokens(tokenId);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", tokenId));
        stakingApp.withdrawTokens(tokenId);
    }

    // -------------------------------------------------------------------------
    // claimRewards
    // -------------------------------------------------------------------------

    function test_claimRewards_byNonOwner_revertsWithNotPositionOwner() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);

        // Act / Assert
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, tokenId, otherUser));
        stakingApp.claimRewards(tokenId);
    }

    function test_claimRewards_forNonexistentToken_revertsWithERC721NonexistentToken() external {
        // Arrange
        uint256 nonexistentTokenId = 999;

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", nonexistentTokenId));
        stakingApp.claimRewards(nonexistentTokenId);
    }

    function test_claimRewards_beforePeriodElapses_revertsWithStakingPeriodNotElapsed() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(StakingPeriodNotElapsed.selector, stakingPeriod_));
        stakingApp.claimRewards(tokenId);
    }

    function test_claimRewards_withNoEther_revertsWithEthTransferFailed() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(EthTransferFailed.selector);
        stakingApp.claimRewards(tokenId);
    }

    function test_claimRewards_afterPeriodElapses_transfersRewardAndResetsTimer() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);
        uint256 ethBefore = address(randomUser).balance;

        // Act
        vm.startPrank(randomUser);
        vm.expectEmit(true, false, false, true);
        emit StakingApp.RewardsClaimed(randomUser, rewardPerPeriod_);
        stakingApp.claimRewards(tokenId);
        vm.stopPrank();

        // Assert
        assertEq(address(randomUser).balance - ethBefore, rewardPerPeriod_);
        assertEq(stakingApp.lastActivity(tokenId), block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Bearer semantics: the NFT owner controls the position
    // -------------------------------------------------------------------------

    function test_claimRewards_afterNftTransfer_newOwnerClaimsAndKeepsAccruedTime() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        _fundContractWithEth();
        vm.warp(block.timestamp + stakingPeriod_);
        vm.prank(randomUser);
        stakingNFT.transferFrom(randomUser, otherUser, tokenId);
        uint256 ethBefore = otherUser.balance;

        // Act
        vm.prank(otherUser);
        stakingApp.claimRewards(tokenId);

        // Assert
        assertEq(otherUser.balance - ethBefore, rewardPerPeriod_);
    }

    function test_claimRewards_afterNftTransfer_previousOwnerReverts() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);
        vm.prank(randomUser);
        stakingNFT.transferFrom(randomUser, otherUser, tokenId);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, tokenId, randomUser));
        stakingApp.claimRewards(tokenId);
    }

    function test_withdrawTokens_afterNftTransfer_newOwnerReceivesTokens() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.prank(randomUser);
        stakingNFT.transferFrom(randomUser, otherUser, tokenId);

        // Act
        vm.prank(otherUser);
        stakingApp.withdrawTokens(tokenId);

        // Assert
        assertEq(IERC20(address(stakingToken)).balanceOf(otherUser), fixedStakingAmount_);
        assertEq(IERC20(address(stakingToken)).balanceOf(randomUser), 0);
    }

    function test_withdrawTokens_afterNftTransfer_previousOwnerReverts() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.prank(randomUser);
        stakingNFT.transferFrom(randomUser, otherUser, tokenId);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, tokenId, randomUser));
        stakingApp.withdrawTokens(tokenId);
    }

    function test_claimRewards_byApprovedOperator_revertsWithNotPositionOwner() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.warp(block.timestamp + stakingPeriod_);
        vm.prank(randomUser);
        stakingNFT.approve(otherUser, tokenId);

        // Act / Assert
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, tokenId, otherUser));
        stakingApp.claimRewards(tokenId);
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
        uint256 tokenId = _stakeAs(randomUser);
        vm.prank(owner_);
        stakingApp.pause();
        vm.warp(block.timestamp + stakingPeriod_);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingApp.claimRewards(tokenId);
    }

    function test_withdrawTokens_whenPaused_succeeds() external {
        // Arrange
        uint256 tokenId = _stakeAs(randomUser);
        vm.prank(owner_);
        stakingApp.pause();

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens(tokenId);

        // Assert
        assertEq(stakingApp.lastActivity(tokenId), 0);
    }

    function test_unpause_afterPause_restoresDeposit() external {
        // Arrange
        vm.startPrank(owner_);
        stakingApp.pause();
        stakingApp.unpause();
        vm.stopPrank();

        // Act
        uint256 tokenId = _stakeAs(randomUser);

        // Assert
        assertEq(stakingNFT.ownerOf(tokenId), randomUser);
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
    uint256 public tokenId;
    bytes public lastRevertReason;

    constructor(address payable stakingApp_) {
        stakingApp = StakingApp(stakingApp_);
    }

    function deposit(uint256 amount_) external {
        tokenId = stakingApp.depositToken(amount_);
    }

    function claim() external {
        stakingApp.claimRewards(tokenId);
    }

    receive() external payable {
        (bool success, bytes memory data) =
            address(stakingApp).call(abi.encodeWithSignature("claimRewards(uint256)", tokenId));
        if (!success) {
            lastRevertReason = data;
        }
    }
}

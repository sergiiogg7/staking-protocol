// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import {IncorrectAmount, StakingPeriodNotElapsed} from "../src/StakingApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingAppFuzz is Test {
    StakingToken stakingToken;
    StakingNFTDescriptor descriptor;
    StakingNFT stakingNFT;
    StakingApp stakingApp;

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    uint256 stakingPeriod_ = 30 days;
    uint256 fixedStakingAmount_ = 1e18;
    uint256 rewardPerPeriod_ = 0.01 ether;

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

    function _fundAndApprove(address user_, uint256 amount_) internal {
        vm.startPrank(owner_);
        stakingToken.mint(amount_);
        assertTrue(stakingToken.transfer(user_, amount_));
        vm.stopPrank();

        vm.prank(user_);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount_);
    }

    // Any amount different from fixStakingAmount must revert with IncorrectAmount.
    function testFuzz_depositToken_withWrongAmount_revertsWithIncorrectAmount(uint256 amount_) external {
        // Arrange
        vm.assume(amount_ != fixedStakingAmount_);

        // Act / Assert
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(IncorrectAmount.selector, fixedStakingAmount_, amount_));
        stakingApp.depositToken(amount_);
    }

    // Claiming before the staking period elapses must always revert.
    function testFuzz_claimRewards_beforeStakingPeriod_revertsWithStakingPeriodNotElapsed(uint256 timeElapsed_)
        external
    {
        // Arrange
        timeElapsed_ = bound(timeElapsed_, 0, stakingPeriod_ - 1);
        _fundAndApprove(randomUser, fixedStakingAmount_);
        vm.prank(randomUser);
        uint256 tokenId = stakingApp.depositToken(fixedStakingAmount_);

        // Act / Assert
        vm.warp(block.timestamp + timeElapsed_);
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(StakingPeriodNotElapsed.selector, stakingPeriod_ - timeElapsed_));
        stakingApp.claimRewards(tokenId);
    }

    // After any elapsed time, a claim pays exactly one reward per completed period and
    // leaves the remainder of the time counting toward the next one.
    function testFuzz_claimRewards_afterAnyElapsedTime_paysCompletedPeriodsAndKeepsRemainder(uint256 timeElapsed_)
        external
    {
        // Arrange
        timeElapsed_ = bound(timeElapsed_, stakingPeriod_, 1000 * stakingPeriod_);
        _fundAndApprove(randomUser, fixedStakingAmount_);
        vm.prank(randomUser);
        uint256 tokenId = stakingApp.depositToken(fixedStakingAmount_);
        uint256 depositTime = block.timestamp;
        uint256 periods = timeElapsed_ / stakingPeriod_;
        vm.deal(owner_, periods * rewardPerPeriod_);
        vm.prank(owner_);
        (bool funded,) = address(stakingApp).call{value: periods * rewardPerPeriod_}("");
        assertTrue(funded);
        vm.warp(depositTime + timeElapsed_);
        uint256 ethBefore = randomUser.balance;

        // Act
        vm.prank(randomUser);
        stakingApp.claimRewards(tokenId);

        // Assert
        assertEq(randomUser.balance - ethBefore, periods * rewardPerPeriod_);
        assertEq(stakingApp.lastActivity(tokenId), depositTime + periods * stakingPeriod_);
        assertEq(stakingApp.claimableRewards(tokenId), 0);
    }

    // Any in-bounds staking period must be accepted at deployment and stored correctly.
    function testFuzz_constructor_withInBoundsPeriod_storesIt(uint256 period_) external {
        // Arrange
        period_ = bound(period_, stakingApp.MIN_STAKING_PERIOD(), stakingApp.MAX_STAKING_PERIOD());

        // Act
        StakingApp app = new StakingApp(
            address(stakingToken),
            address(descriptor),
            owner_,
            period_,
            fixedStakingAmount_,
            rewardPerPeriod_,
            "STK Position",
            "STKP"
        );

        // Assert
        assertEq(app.stakingPeriod(), period_);
    }

    // Any out-of-bounds staking period must make the deployment revert.
    function testFuzz_constructor_withOutOfBoundsPeriod_reverts(uint256 period_) external {
        // Arrange
        vm.assume(period_ < stakingApp.MIN_STAKING_PERIOD() || period_ > stakingApp.MAX_STAKING_PERIOD());

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(InvalidStakingPeriod.selector, period_));
        new StakingApp(
            address(stakingToken),
            address(descriptor),
            owner_,
            period_,
            fixedStakingAmount_,
            rewardPerPeriod_,
            "STK Position",
            "STKP"
        );
    }
}

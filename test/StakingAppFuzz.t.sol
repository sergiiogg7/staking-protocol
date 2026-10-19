// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import {IncorrectAmount, StakingPeriodNotElapsed} from "../src/StakingApp.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
        uint64 nonce = vm.getNonce(address(this));
        address predictedStakingApp = vm.computeCreateAddress(address(this), nonce + 3);

        stakingToken = new StakingToken("Staking Token", "STK", owner_);
        descriptor = new StakingNFTDescriptor();
        stakingNFT = new StakingNFT("STK Position", "STKP", predictedStakingApp, owner_, address(descriptor));
        stakingApp = new StakingApp(
            address(stakingToken), address(stakingNFT), owner_, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_
        );
    }

    function _fundAndApprove(address user_, uint256 amount_) internal {
        vm.startPrank(owner_);
        stakingToken.mint(amount_);
        stakingToken.transfer(user_, amount_);
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
        stakingApp.depositToken(fixedStakingAmount_);

        // Act / Assert
        vm.warp(block.timestamp + timeElapsed_);
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(StakingPeriodNotElapsed.selector, stakingPeriod_ - timeElapsed_));
        stakingApp.claimRewards();
    }

    // The owner can set any staking period and it must be stored correctly.
    function testFuzz_changeStakingPeriod_byOwner_storesAnyValue(uint256 newPeriod_) external {
        // Arrange / Act
        vm.prank(owner_);
        stakingApp.changeStakingPeriod(newPeriod_);

        // Assert
        assertEq(stakingApp.stakingPeriod(), newPeriod_);
    }
}

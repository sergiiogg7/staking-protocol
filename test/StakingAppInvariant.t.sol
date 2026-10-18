// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingApp.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Handler wraps StakingApp calls so Foundry can call them with valid state.
contract StakingAppHandler is Test {
    StakingToken public stakingToken;
    StakingApp public stakingApp;

    address public owner;
    address[] public stakers;

    // Tracks total tokens deposited that have not been withdrawn yet.
    uint256 public totalDeposited;

    constructor(StakingToken stakingToken_, StakingApp stakingApp_, address owner_) {
        stakingToken = stakingToken_;
        stakingApp = stakingApp_;
        owner = owner_;

        // Pre-fund a set of staker addresses so the handler can deposit on their behalf.
        for (uint256 i = 0; i < 5; i++) {
            address staker = vm.addr(100 + i);
            stakers.push(staker);
        }
    }

    function deposit(uint256 stakerIndex_) external {
        stakerIndex_ = bound(stakerIndex_, 0, stakers.length - 1);
        address staker = stakers[stakerIndex_];

        if (stakingApp.userBalance(staker) != 0) return;

        uint256 amount = stakingApp.fixStakingAmount();

        vm.startPrank(owner);
        stakingToken.mint(amount);
        stakingToken.transfer(staker, amount);
        vm.stopPrank();

        vm.startPrank(staker);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount);
        stakingApp.depositToken(amount);
        vm.stopPrank();

        totalDeposited += amount;
    }

    function withdraw(uint256 stakerIndex_) external {
        stakerIndex_ = bound(stakerIndex_, 0, stakers.length - 1);
        address staker = stakers[stakerIndex_];

        if (stakingApp.userBalance(staker) == 0) return;

        uint256 amount = stakingApp.userBalance(staker);

        vm.prank(staker);
        stakingApp.withdrawTokens();

        totalDeposited -= amount;
    }
}

contract StakingAppInvariant is Test {
    StakingToken stakingToken;
    StakingApp stakingApp;
    StakingAppHandler handler;

    address owner = vm.addr(1);
    uint256 stakingPeriod_ = 30 days;
    uint256 fixedStakingAmount_ = 1e18;
    uint256 rewardPerPeriod_ = 0.01 ether;

    function setUp() external {
        stakingToken = new StakingToken("Staking Token", "STK", owner);
        stakingApp = new StakingApp(address(stakingToken), owner, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_);
        handler = new StakingAppHandler(stakingToken, stakingApp, owner);

        targetContract(address(handler));
    }

    // The contract's token balance must always cover all recorded deposits.
    function invariant_tokenBalanceCoversTotalDeposited() external view {
        assertGe(
            IERC20(address(stakingToken)).balanceOf(address(stakingApp)),
            handler.totalDeposited()
        );
    }
}

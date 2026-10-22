// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Handler wraps StakingApp calls so Foundry can call them with valid state.
contract StakingAppHandler is Test {
    StakingToken public stakingToken;
    StakingNFT public stakingNFT;
    StakingApp public stakingApp;

    address public owner;
    address[] public stakers;

    uint256 public ghostEthFunded;
    uint256 public ghostEthClaimed;

    constructor(StakingToken stakingToken_, StakingNFT stakingNFT_, StakingApp stakingApp_, address owner_) {
        stakingToken = stakingToken_;
        stakingNFT = stakingNFT_;
        stakingApp = stakingApp_;
        owner = owner_;

        // Pre-fund a set of staker addresses so the handler can deposit on their behalf.
        for (uint256 i = 0; i < 5; i++) {
            stakers.push(vm.addr(100 + i));
        }
    }

    function deposit(uint256 stakerIndex_) external {
        stakerIndex_ = bound(stakerIndex_, 0, stakers.length - 1);
        address staker = stakers[stakerIndex_];

        if (stakingApp.userTokenId(staker) != 0) return;

        uint256 amount = stakingApp.fixStakingAmount();

        vm.startPrank(owner);
        stakingToken.mint(amount);
        assertTrue(stakingToken.transfer(staker, amount));
        vm.stopPrank();

        vm.startPrank(staker);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount);
        stakingApp.depositToken(amount);
        vm.stopPrank();
    }

    function withdraw(uint256 stakerIndex_) external {
        stakerIndex_ = bound(stakerIndex_, 0, stakers.length - 1);
        address staker = stakers[stakerIndex_];

        if (stakingApp.userTokenId(staker) == 0) return;

        vm.prank(staker);
        stakingApp.withdrawTokens();
    }

    function claim(uint256 stakerIndex_, uint256 elapsed_) external {
        stakerIndex_ = bound(stakerIndex_, 0, stakers.length - 1);
        address staker = stakers[stakerIndex_];

        if (stakingApp.userTokenId(staker) == 0) return;

        elapsed_ = bound(elapsed_, 0, 60 days);
        vm.warp(block.timestamp + elapsed_);
        if (block.timestamp - stakingApp.lastActivity(staker) < stakingApp.stakingPeriod()) return;

        uint256 reward = stakingApp.rewardPerPeriod();
        if (address(stakingApp).balance < reward) {
            vm.deal(owner, reward);
            vm.prank(owner);
            (bool ok,) = address(stakingApp).call{value: reward}("");
            assertTrue(ok);
            ghostEthFunded += reward;
        }

        vm.prank(staker);
        stakingApp.claimRewards();
        ghostEthClaimed += reward;
    }

    function stakersLength() external view returns (uint256) {
        return stakers.length;
    }
}

contract StakingAppInvariant is Test {
    StakingToken stakingToken;
    StakingNFTDescriptor descriptor;
    StakingNFT stakingNFT;
    StakingApp stakingApp;
    StakingAppHandler handler;

    address owner = vm.addr(1);
    uint256 stakingPeriod_ = 30 days;
    uint256 fixedStakingAmount_ = 1e18;
    uint256 rewardPerPeriod_ = 0.01 ether;

    function setUp() external {
        uint64 nonce = vm.getNonce(address(this));
        address predictedStakingApp = vm.computeCreateAddress(address(this), nonce + 3);

        stakingToken = new StakingToken("Staking Token", "STK", owner);
        descriptor = new StakingNFTDescriptor();
        stakingNFT = new StakingNFT("STK Position", "STKP", predictedStakingApp, owner, address(descriptor));
        stakingApp = new StakingApp(
            address(stakingToken), address(stakingNFT), owner, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_
        );
        handler = new StakingAppHandler(stakingToken, stakingNFT, stakingApp, owner);

        targetContract(address(handler));
    }

    // Each open position holds exactly fixStakingAmount tokens; the contract's token balance
    // must therefore equal the number of active NFTs times the fixed staking amount.
    function invariant_nftSupplyTimesAmountEqualsTokenBalance() external view {
        assertEq(
            stakingNFT.totalPositions() * stakingApp.fixStakingAmount(),
            IERC20(address(stakingToken)).balanceOf(address(stakingApp))
        );
    }

    // The app's ETH balance is exactly what the owner funded minus what stakers claimed.
    function invariant_ethBalanceEqualsFundedMinusClaimed() external view {
        assertEq(address(stakingApp).balance, handler.ghostEthFunded() - handler.ghostEthClaimed());
    }

    // userTokenId and NFT ownership never diverge: a staker owns their tracked NFT, or no NFT at all.
    function invariant_userTokenIdMatchesNftOwnership() external view {
        uint256 active;
        for (uint256 i = 0; i < handler.stakersLength(); i++) {
            address staker = handler.stakers(i);
            uint256 tokenId = stakingApp.userTokenId(staker);
            if (tokenId == 0) {
                assertEq(stakingNFT.balanceOf(staker), 0);
            } else {
                assertEq(stakingNFT.ownerOf(tokenId), staker);
                assertEq(stakingNFT.balanceOf(staker), 1);
                active++;
            }
        }
        assertEq(active, stakingNFT.totalPositions());
    }
}

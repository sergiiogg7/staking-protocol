// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Handler wraps StakingApp calls so Foundry can call them with valid state.
// It tracks every open position by token ID and always acts as the current NFT owner.
contract StakingAppHandler is Test {
    StakingToken public stakingToken;
    StakingNFT public stakingNFT;
    StakingApp public stakingApp;

    address public owner;
    address[] public stakers;
    uint256[] public openTokenIds;

    uint256 public ghostEthFunded;
    uint256 public ghostEthClaimed;
    uint256 public ghostClaimsLeavingRewards;
    uint256 public ghostEthWithdrawn;
    uint256 public ghostWithdrawsWhileOpen;

    constructor(StakingToken stakingToken_, StakingNFT stakingNFT_, StakingApp stakingApp_, address owner_) {
        stakingToken = stakingToken_;
        stakingNFT = stakingNFT_;
        stakingApp = stakingApp_;
        owner = owner_;

        for (uint256 i = 0; i < 5; i++) {
            stakers.push(vm.addr(100 + i));
        }
    }

    function deposit(uint256 stakerIndex_) external {
        address staker = stakers[bound(stakerIndex_, 0, stakers.length - 1)];
        uint256 amount = stakingApp.fixStakingAmount();

        vm.startPrank(owner);
        stakingToken.mint(amount);
        assertTrue(stakingToken.transfer(staker, amount));
        vm.stopPrank();

        vm.startPrank(staker);
        IERC20(address(stakingToken)).approve(address(stakingApp), amount);
        uint256 tokenId = stakingApp.depositToken(amount);
        vm.stopPrank();

        openTokenIds.push(tokenId);
    }

    function withdraw(uint256 positionIndex_) external {
        if (openTokenIds.length == 0) return;
        uint256 index = bound(positionIndex_, 0, openTokenIds.length - 1);
        uint256 tokenId = openTokenIds[index];

        vm.prank(stakingNFT.ownerOf(tokenId));
        stakingApp.withdrawTokens(tokenId);

        openTokenIds[index] = openTokenIds[openTokenIds.length - 1];
        openTokenIds.pop();
    }

    function transferPosition(uint256 positionIndex_, uint256 toIndex_) external {
        if (openTokenIds.length == 0) return;
        uint256 tokenId = openTokenIds[bound(positionIndex_, 0, openTokenIds.length - 1)];
        address holder = stakingNFT.ownerOf(tokenId);
        address to = stakers[bound(toIndex_, 0, stakers.length - 1)];

        vm.prank(holder);
        stakingNFT.transferFrom(holder, to, tokenId);
    }

    function claim(uint256 positionIndex_, uint256 elapsed_) external {
        if (openTokenIds.length == 0) return;
        uint256 tokenId = openTokenIds[bound(positionIndex_, 0, openTokenIds.length - 1)];

        elapsed_ = bound(elapsed_, 0, 60 days);
        vm.warp(block.timestamp + elapsed_);
        uint256 period = stakingApp.stakingPeriod();
        uint256 sinceLastActivity = block.timestamp - stakingApp.lastActivity(tokenId);
        if (sinceLastActivity < period) return;

        uint256 reward = (sinceLastActivity / period) * stakingApp.rewardPerPeriod();
        if (address(stakingApp).balance < reward) {
            vm.deal(owner, reward);
            vm.prank(owner);
            (bool ok,) = address(stakingApp).call{value: reward}("");
            assertTrue(ok);
            ghostEthFunded += reward;
        }

        vm.prank(stakingNFT.ownerOf(tokenId));
        stakingApp.claimRewards(tokenId);
        ghostEthClaimed += reward;

        if (stakingApp.claimableRewards(tokenId) != 0) ghostClaimsLeavingRewards++;
    }

    function ownerFundsEther(uint256 amount_) external {
        amount_ = bound(amount_, 1, 10 ether);

        vm.deal(owner, amount_);
        vm.prank(owner);
        (bool ok,) = address(stakingApp).call{value: amount_}("");
        assertTrue(ok);
        ghostEthFunded += amount_;
    }

    function ownerWithdrawsEther() external {
        uint256 openPositions = stakingNFT.totalPositions();
        uint256 balance = address(stakingApp).balance;

        vm.prank(owner);
        try stakingApp.withdrawEther() {
            if (openPositions != 0) ghostWithdrawsWhileOpen++;
            ghostEthWithdrawn += balance;
        } catch {}
    }

    function stakersLength() external view returns (uint256) {
        return stakers.length;
    }

    function openTokenIdsLength() external view returns (uint256) {
        return openTokenIds.length;
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
        stakingToken = new StakingToken("Staking Token", "STK", owner);
        descriptor = new StakingNFTDescriptor();
        stakingApp = new StakingApp(
            address(stakingToken),
            address(descriptor),
            owner,
            stakingPeriod_,
            fixedStakingAmount_,
            rewardPerPeriod_,
            "STK Position",
            "STKP"
        );
        stakingNFT = stakingApp.stakingNFT();
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

    // The app's ETH balance is exactly what the owner funded minus what stakers claimed and the owner recovered.
    function invariant_ethBalanceEqualsFundedMinusClaimedAndWithdrawn() external view {
        assertEq(
            address(stakingApp).balance,
            handler.ghostEthFunded() - handler.ghostEthClaimed() - handler.ghostEthWithdrawn()
        );
    }

    // The owner can never take ETH out while a position is open, so withdrawing ETH
    // never reduces what a staker is able to collect.
    function invariant_etherNeverWithdrawnWhilePositionsOpen() external view {
        assertEq(handler.ghostWithdrawsWhileOpen(), 0);
    }

    // Every position the handler considers open is a live NFT with a running timer,
    // and the handler's count matches the NFT contract's own count.
    function invariant_openPositionsAreLiveWithTimer() external view {
        assertEq(handler.openTokenIdsLength(), stakingNFT.totalPositions());
        for (uint256 i = 0; i < handler.openTokenIdsLength(); i++) {
            uint256 tokenId = handler.openTokenIds(i);
            assertGt(stakingApp.lastActivity(tokenId), 0);
            assertLe(stakingApp.lastActivity(tokenId), block.timestamp);
            assertTrue(stakingNFT.ownerOf(tokenId) != address(0));
        }
    }

    // A claim pays every completed period: right after it, nothing is left to claim.
    function invariant_claimLeavesNothingClaimable() external view {
        assertEq(handler.ghostClaimsLeavingRewards(), 0);
    }

    // Positions only ever move between known stakers, so their NFT balances add up to the total.
    function invariant_stakerNftBalancesSumToTotalPositions() external view {
        uint256 sum;
        for (uint256 i = 0; i < handler.stakersLength(); i++) {
            sum += stakingNFT.balanceOf(handler.stakers(i));
        }
        assertEq(sum, stakingNFT.totalPositions());
    }
}

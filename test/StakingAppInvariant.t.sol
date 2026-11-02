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
        if (block.timestamp - stakingApp.lastActivity(tokenId) < stakingApp.stakingPeriod()) return;

        uint256 reward = stakingApp.rewardPerPeriod();
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

    // The app's ETH balance is exactly what the owner funded minus what stakers claimed.
    function invariant_ethBalanceEqualsFundedMinusClaimed() external view {
        assertEq(address(stakingApp).balance, handler.ghostEthFunded() - handler.ghostEthClaimed());
    }

    // Every position the handler considers open is a live NFT with a running timer,
    // and the handler's count matches the NFT contract's own count.
    function invariant_openPositionsAreLiveWithTimer() external view {
        assertEq(handler.openTokenIdsLength(), stakingNFT.totalPositions());
        for (uint256 i = 0; i < handler.openTokenIdsLength(); i++) {
            uint256 tokenId = handler.openTokenIds(i);
            assertGt(stakingApp.lastActivity(tokenId), 0);
            assertTrue(stakingNFT.ownerOf(tokenId) != address(0));
        }
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

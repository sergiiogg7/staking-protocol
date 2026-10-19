// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";

contract Deploy is Script {
    function run() external {
        address owner = vm.envAddress("OWNER_ADDRESS");
        uint256 stakingPeriod = vm.envUint("STAKING_PERIOD");
        uint256 fixStakingAmount = vm.envUint("FIX_STAKING_AMOUNT");
        uint256 rewardPerPeriod = vm.envUint("REWARD_PER_PERIOD");

        vm.startBroadcast();

        // Deploy order: token(nonce), descriptor(nonce+1), nft(nonce+2), app(nonce+3).
        // StakingNFT needs StakingApp's address at construction time; predict it from the nonce.
        uint64 nonce = vm.getNonce(msg.sender);
        address predictedApp = vm.computeCreateAddress(msg.sender, nonce + 3);

        StakingToken token = new StakingToken("Staking Token", "STK", owner);
        StakingNFTDescriptor descriptor = new StakingNFTDescriptor();
        StakingNFT nft = new StakingNFT("STK Position", "STKP", predictedApp, owner, address(descriptor));
        StakingApp app =
            new StakingApp(address(token), address(nft), owner, stakingPeriod, fixStakingAmount, rewardPerPeriod);

        vm.stopBroadcast();

        console.log("StakingToken        deployed at:", address(token));
        console.log("StakingNFTDescriptor deployed at:", address(descriptor));
        console.log("StakingNFT          deployed at:", address(nft));
        console.log("StakingApp          deployed at:", address(app));
    }
}

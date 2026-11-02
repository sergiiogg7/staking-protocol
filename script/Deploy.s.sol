// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

        StakingToken token = new StakingToken("Staking Token", "STK", owner);
        StakingNFTDescriptor descriptor = new StakingNFTDescriptor();
        StakingApp app = new StakingApp(
            address(token),
            address(descriptor),
            owner,
            stakingPeriod,
            fixStakingAmount,
            rewardPerPeriod,
            "STK Position",
            "STKP"
        );
        StakingNFT nft = app.stakingNFT();

        vm.stopBroadcast();

        console.log("StakingToken        deployed at:", address(token));
        console.log("StakingNFTDescriptor deployed at:", address(descriptor));
        console.log("StakingNFT          deployed at:", address(nft));
        console.log("StakingApp          deployed at:", address(app));
    }
}

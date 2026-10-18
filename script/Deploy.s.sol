// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/StakingToken.sol";
import "../src/StakingApp.sol";

contract Deploy is Script {
    function run() external {
        address owner = vm.envAddress("OWNER_ADDRESS");
        uint256 stakingPeriod = vm.envUint("STAKING_PERIOD");
        uint256 fixStakingAmount = vm.envUint("FIX_STAKING_AMOUNT");
        uint256 rewardPerPeriod = vm.envUint("REWARD_PER_PERIOD");

        vm.startBroadcast();

        StakingToken token = new StakingToken("Staking Token", "STK", owner);

        StakingApp app = new StakingApp(address(token), owner, stakingPeriod, fixStakingAmount, rewardPerPeriod);

        vm.stopBroadcast();

        console.log("StakingToken deployed at:", address(token));
        console.log("StakingApp  deployed at:", address(app));
    }
}

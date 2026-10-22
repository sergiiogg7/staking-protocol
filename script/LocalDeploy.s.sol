// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";

/// @dev Local-only deploy for manual testing. Uses Anvil's deterministic accounts.
///      Produces the same contract addresses as deployedContracts.ts every time
///      because Anvil resets nonces to 0 on each fresh start.
contract LocalDeploy is Script {
    address constant OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil account #0

    uint256 constant STAKING_PERIOD     = 90;        // 90 seconds — short enough to test claim
    uint256 constant FIX_STAKING_AMOUNT = 1e18;      // 1 STK
    uint256 constant REWARD_PER_PERIOD  = 0.01 ether;
    uint256 constant TOKENS_PER_ACCOUNT = 100e18;    // 100 STK per account
    uint256 constant ETH_FUND           = 2 ether;   // rewards pool

    function run() external {
        vm.startBroadcast();

        // Nonce prediction so StakingNFT can reference StakingApp at construction time.
        uint64 nonce = vm.getNonce(msg.sender);
        address predictedApp = vm.computeCreateAddress(msg.sender, nonce + 3);

        StakingToken token = new StakingToken("Staking Token", "STK", OWNER);
        StakingNFTDescriptor descriptor = new StakingNFTDescriptor();
        StakingNFT nft = new StakingNFT("STK Position", "STKP", predictedApp, OWNER, address(descriptor));
        StakingApp app = new StakingApp(
            address(token), address(nft), OWNER,
            STAKING_PERIOD, FIX_STAKING_AMOUNT, REWARD_PER_PERIOD
        );

        // Pre-fund all 10 Anvil accounts with 100 STK each.
        // Account #0 is the broadcaster/owner: mint gives tokens to it, then distribute to #1-#9.
        address[] memory recipients = new address[](9);
        recipients[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil #1
        recipients[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Anvil #2
        recipients[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Anvil #3
        recipients[3] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Anvil #4
        recipients[4] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc; // Anvil #5
        recipients[5] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9; // Anvil #6
        recipients[6] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955; // Anvil #7
        recipients[7] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f; // Anvil #8
        recipients[8] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720; // Anvil #9

        uint256[] memory amounts = new uint256[](9);
        for (uint256 i = 0; i < 9; i++) {
            amounts[i] = TOKENS_PER_ACCOUNT;
        }

        token.mint(TOKENS_PER_ACCOUNT * 10); // 1000 STK → owner (#0)
        token.distributeTokens(recipients, amounts); // 900 STK → accounts #1-#9; #0 keeps 100

        // Fund StakingApp with ETH for rewards. receive() is onlyOwner — broadcaster is owner.
        payable(address(app)).transfer(ETH_FUND);

        vm.stopBroadcast();

        console.log("=== LOCAL DEV DEPLOY ===");
        console.log("StakingToken:        ", address(token));
        console.log("StakingNFTDescriptor:", address(descriptor));
        console.log("StakingNFT:          ", address(nft));
        console.log("StakingApp:          ", address(app));
        console.log("");
        console.log("Staking period: 90 seconds");
        console.log("Tokens per account: 100 STK (#0-#9)");
        console.log("StakingApp funded: 2 ETH");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingTokenTest is Test {
    StakingToken stakingToken;
    string name_ = "Staking Token";
    string symbol_ = "STK";
    address randomUser = vm.addr(1);

    function setUp() public {
        stakingToken = new StakingToken(name_, symbol_);
    }

    function testStakingTokenMintsCorrectly() public {
        vm.startPrank(randomUser);
        uint256 amount = 1 ether;

        //Token balance previous
        uint256 balanceBefore_ = IERC20(address(stakingToken)).balanceOf(randomUser); // UserA = 51
        stakingToken.mint(amount); // Mint 1 token
        //Token balance after
        uint256 balanceAfter_ = IERC20(address(stakingToken)).balanceOf(randomUser); // UserB = 52

        assert(balanceAfter_ - balanceBefore_ == amount); // 52 - 51 == 1 ?

        vm.stopPrank();
    }
}

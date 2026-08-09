// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 1e18;

    constructor(string memory name_, string memory symbol_, address owner_) ERC20(name_, symbol_) Ownable(owner_) {}

    function mint(uint256 amount_) external onlyOwner {
        require(totalSupply() + amount_ <= MAX_SUPPLY, "Max supply exceeded");
        _mint(msg.sender, amount_);
    }

    function distributeTokens(address[] calldata recipients_, uint256[] calldata amounts_) external onlyOwner {
        require(recipients_.length == amounts_.length, "Length mismatch");
        for (uint256 i = 0; i < recipients_.length; i++) {
            require(recipients_[i] != address(0), "Invalid recipient");
            _transfer(msg.sender, recipients_[i], amounts_[i]);
        }
    }
}

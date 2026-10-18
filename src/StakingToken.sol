// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

error MaxSupplyExceeded(uint256 available, uint256 requested);
error LengthMismatch(uint256 recipientsLength, uint256 amountsLength);
error InvalidRecipient(uint256 index);

contract StakingToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 1e18;

    constructor(string memory name_, string memory symbol_, address owner_) ERC20(name_, symbol_) Ownable(owner_) {}

    function mint(uint256 amount_) external onlyOwner {
        uint256 available = MAX_SUPPLY - totalSupply();
        if (amount_ > available) revert MaxSupplyExceeded(available, amount_);
        _mint(msg.sender, amount_);
    }

    function distributeTokens(address[] calldata recipients_, uint256[] calldata amounts_) external onlyOwner {
        if (recipients_.length != amounts_.length) revert LengthMismatch(recipients_.length, amounts_.length);
        for (uint256 i = 0; i < recipients_.length; i++) {
            if (recipients_[i] == address(0)) revert InvalidRecipient(i);
            _transfer(msg.sender, recipients_[i], amounts_[i]);
        }
    }
}

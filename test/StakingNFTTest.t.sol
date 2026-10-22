// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../src/StakingNFTDescriptor.sol";
import "../src/StakingNFT.sol";
import "../src/StakingApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Unauthorized, NonexistentToken, InvalidDescriptor} from "../src/StakingNFT.sol";

contract StakingNFTTest is Test {
    StakingToken stakingToken;
    StakingNFTDescriptor descriptor;
    StakingNFT stakingNFT;
    StakingApp stakingApp;

    address owner_ = vm.addr(1);
    address randomUser = vm.addr(2);
    address unauthorized_ = vm.addr(3);
    address secondUser = vm.addr(4);
    uint256 fixedStakingAmount_ = 10;
    uint256 stakingPeriod_ = 30 days;
    uint256 rewardPerPeriod_ = 0.01 ether;

    function setUp() external {
        uint64 nonce = vm.getNonce(address(this));
        address predictedStakingApp = vm.computeCreateAddress(address(this), nonce + 3);

        stakingToken = new StakingToken("Staking Token", "STK", owner_);
        descriptor = new StakingNFTDescriptor();
        stakingNFT = new StakingNFT("STK Position", "STKP", predictedStakingApp, owner_, address(descriptor));
        stakingApp = new StakingApp(
            address(stakingToken), address(stakingNFT), owner_, stakingPeriod_, fixedStakingAmount_, rewardPerPeriod_
        );
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _createPosition(address user_) internal returns (uint256 tokenId_) {
        vm.startPrank(owner_);
        stakingToken.mint(fixedStakingAmount_);
        assertTrue(stakingToken.transfer(user_, fixedStakingAmount_));
        vm.stopPrank();

        vm.startPrank(user_);
        IERC20(address(stakingToken)).approve(address(stakingApp), fixedStakingAmount_);
        stakingApp.depositToken(fixedStakingAmount_);
        vm.stopPrank();

        return stakingApp.userTokenId(user_);
    }

    // -------------------------------------------------------------------------
    // Access control — mint / burn
    // -------------------------------------------------------------------------

    function test_stakingApp_addressIsSetCorrectly() external view {
        // Assert
        assertEq(stakingNFT.stakingApp(), address(stakingApp));
    }

    function test_mint_byUnauthorized_revertsWithUnauthorized() external {
        // Arrange / Act / Assert
        vm.prank(unauthorized_);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, unauthorized_));
        stakingNFT.mint(randomUser, fixedStakingAmount_, block.timestamp);
    }

    function test_burn_byUnauthorized_revertsWithUnauthorized() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);

        // Act / Assert
        vm.prank(unauthorized_);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, unauthorized_));
        stakingNFT.burn(tokenId);
    }

    // -------------------------------------------------------------------------
    // mint
    // -------------------------------------------------------------------------

    function test_mint_byStakingApp_mintsNFTToRecipient() external {
        // Arrange / Act
        uint256 tokenId = _createPosition(randomUser);

        // Assert
        assertEq(stakingNFT.ownerOf(tokenId), randomUser);
    }

    function test_mint_storesDepositAmountAndTimestamp() external {
        // Arrange
        uint256 depositTime = block.timestamp;

        // Act
        uint256 tokenId = _createPosition(randomUser);

        // Assert
        assertEq(stakingNFT.depositAmount(tokenId), fixedStakingAmount_);
        assertEq(stakingNFT.depositTimestamp(tokenId), depositTime);
    }

    function test_mint_firstTokenIdIsOne() external {
        // Act
        uint256 tokenId = _createPosition(randomUser);

        // Assert
        assertEq(tokenId, 1);
    }

    function test_mint_tokenIdIncrementsMonotonically() external {
        // Arrange
        uint256 firstTokenId = _createPosition(randomUser);

        // Act
        uint256 secondTokenId = _createPosition(secondUser);

        // Assert
        assertEq(secondTokenId, firstTokenId + 1);
    }

    function test_mint_incrementsTotalPositions() external {
        // Arrange
        assertEq(stakingNFT.totalPositions(), 0);

        // Act
        _createPosition(randomUser);

        // Assert
        assertEq(stakingNFT.totalPositions(), 1);
    }

    // -------------------------------------------------------------------------
    // burn
    // -------------------------------------------------------------------------

    function test_burn_byStakingApp_removesNFT() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        // Assert — OZ v5 reverts with ERC721NonexistentToken on ownerOf for burned tokens
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", tokenId));
        stakingNFT.ownerOf(tokenId);
    }

    function test_burn_clearsDepositAmountAndTimestamp() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        // Assert
        assertEq(stakingNFT.depositAmount(tokenId), 0);
        assertEq(stakingNFT.depositTimestamp(tokenId), 0);
    }

    function test_burn_decrementsTotalPositions() external {
        // Arrange
        _createPosition(randomUser);
        assertEq(stakingNFT.totalPositions(), 1);

        // Act
        vm.prank(randomUser);
        stakingApp.withdrawTokens();

        // Assert
        assertEq(stakingNFT.totalPositions(), 0);
    }

    // -------------------------------------------------------------------------
    // setDescriptor
    // -------------------------------------------------------------------------

    function test_setDescriptor_byOwner_updatesDescriptor() external {
        // Arrange
        StakingNFTDescriptor newDescriptor = new StakingNFTDescriptor();

        // Act
        vm.prank(owner_);
        stakingNFT.setDescriptor(address(newDescriptor));

        // Assert
        assertEq(address(stakingNFT.descriptor()), address(newDescriptor));
    }

    function test_setDescriptor_withZeroAddress_revertsWithInvalidDescriptor() external {
        // Arrange / Act / Assert
        vm.prank(owner_);
        vm.expectRevert(InvalidDescriptor.selector);
        stakingNFT.setDescriptor(address(0));
    }

    function test_setDescriptor_byNonOwner_reverts() external {
        // Arrange
        StakingNFTDescriptor newDescriptor = new StakingNFTDescriptor();

        // Act / Assert
        vm.prank(unauthorized_);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", unauthorized_));
        stakingNFT.setDescriptor(address(newDescriptor));
    }

    // -------------------------------------------------------------------------
    // tokenURI
    // -------------------------------------------------------------------------

    function test_tokenURI_forNonexistentToken_revertsWithNonexistentToken() external {
        // Arrange / Act / Assert
        vm.expectRevert(abi.encodeWithSelector(NonexistentToken.selector, 999));
        stakingNFT.tokenURI(999);
    }

    function test_tokenURI_forExistingToken_startsWithDataUriPrefix() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);

        // Act
        string memory uri = stakingNFT.tokenURI(tokenId);

        // Assert — verify the JSON data URI scheme prefix is correct
        bytes memory uriBytes = bytes(uri);
        bytes memory expectedPrefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < expectedPrefix.length; i++) {
            assertEq(uriBytes[i], expectedPrefix[i]);
        }
    }

    function test_tokenURI_afterDescriptorUpdate_usesNewDescriptor() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);
        string memory uriBefore = stakingNFT.tokenURI(tokenId);

        StakingNFTDescriptor newDescriptor = new StakingNFTDescriptor();
        vm.prank(owner_);
        stakingNFT.setDescriptor(address(newDescriptor));

        // Act
        string memory uriAfter = stakingNFT.tokenURI(tokenId);

        // Assert — same content since both descriptors are identical implementations,
        // but the call now goes through the new contract address
        assertEq(keccak256(bytes(uriBefore)), keccak256(bytes(uriAfter)));
        assertEq(address(stakingNFT.descriptor()), address(newDescriptor));
    }

    // -------------------------------------------------------------------------
    // Transferability
    // -------------------------------------------------------------------------

    function test_transfer_positionNFTIsTransferableToAnotherWallet() external {
        // Arrange
        uint256 tokenId = _createPosition(randomUser);
        address recipient = vm.addr(99);

        // Act
        vm.prank(randomUser);
        stakingNFT.transferFrom(randomUser, recipient, tokenId);

        // Assert
        assertEq(stakingNFT.ownerOf(tokenId), recipient);
    }
}

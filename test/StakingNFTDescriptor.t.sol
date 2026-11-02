// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../src/StakingNFTDescriptor.sol";

contract StakingNFTDescriptorTest is Test {
    StakingNFTDescriptor descriptor;

    uint256 tokenId_ = 7;
    uint256 amount_ = 1e18;
    uint256 timestamp_ = 1793577600;

    function setUp() external {
        descriptor = new StakingNFTDescriptor();
    }

    function _expectedSvg() internal view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">',
            '<rect width="300" height="300" rx="16" fill="#0f172a"/>',
            '<text x="150" y="60" font-family="monospace" font-size="14" fill="#94a3b8" text-anchor="middle">STK Staking Position</text>',
            '<text x="150" y="130" font-family="monospace" font-size="40" font-weight="bold" fill="#f8fafc" text-anchor="middle">#7</text>',
            '<text x="150" y="185" font-family="monospace" font-size="13" fill="#64748b" text-anchor="middle">Amount (wei): ',
            vm.toString(amount_),
            "</text></svg>"
        );
    }

    function test_constructTokenURI_buildsJsonWithAmountInWeiAndDateAttribute() external view {
        // Arrange
        string memory imageUri = string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(_expectedSvg())));
        string memory expectedJson = string.concat(
            '{"name":"Staking Position #7","description":"STK fixed-amount staking position","image":"',
            imageUri,
            '","attributes":[{"trait_type":"Amount (wei)","value":"1000000000000000000"},',
            '{"display_type":"date","trait_type":"Staked At","value":1793577600}]}'
        );
        string memory expectedUri = string.concat("data:application/json;base64,", Base64.encode(bytes(expectedJson)));

        // Act
        string memory uri = descriptor.constructTokenURI(tokenId_, amount_, timestamp_);

        // Assert
        assertEq(uri, expectedUri);
    }
}

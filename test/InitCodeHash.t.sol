// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {Singlesig} from "src/singlesig/Singlesig.sol";

// Singlesig inithash: 0xf911e320d18e7274491e7ab207bfff830e2926248f86c6a987668e8e72e1ed77
// salt 0x000000000000000000000000000000000000000016c7768a8c7a2824b846321d => 0x000000dE1E80ea5a234FB5488fee2584251BC7e8

// Registry inithash: 0x78bdba7d5e0c91d9aedc93c97bf84433daaf008a83bfe921c2d27ab77301d6d9
// salt 0x0000000000000000000000000000000000000000fbe49ecfc3decb1164228b89 => 0x0000000000006DE22EeA995bE2f0511186b8e013 => 16777216

contract InitCodeHashTest is Test {
    DelegateRegistry reg;
    Singlesig sig;

    function setUp() public {
        reg = new DelegateRegistry();
        sig = new Singlesig(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215);
    }

    function getInitHash() public pure returns (bytes32) {
        bytes memory initCode = type(DelegateRegistry).creationCode;
        // bytes memory initCode = abi.encodePacked(type(Singlesig).creationCode, abi.encode(address(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215)));
        // console2.logBytes(initCode);

        return keccak256(abi.encodePacked(initCode));
    }

    function testInitHash() public {
        bytes32 initHash = getInitHash();
        emit log_bytes32(initHash);
    }
}

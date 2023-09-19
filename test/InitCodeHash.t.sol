// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {Singlesig} from "src/singlesig/Singlesig.sol";

// Singlesig(foobardev) = 0x126583f6c09a06513f110bf1754633061630875211d1322b6e86c984481a003a
// Seed 0x0000000000000000000000000000000000000000010611e6a73e9c03d5b15d36 => 0x0000000081117a317387DA0AD2873821cb7E40f8

// With constructor params appended: 0x52d978fa1df058a3037a1db29546caf0c19bc9c602110fa48f6ccf39f5541bb0
// Per https://twitter.com/0mnus/status/1691193474228641792

// Delegate address: 0x6ed7d526b020780f694f3c10dfb25e1b134d3215
// inithash: 0xcca90965f49f0b18661a05a21aea51ef95c0d27e2c3f216e54c928968e778af2
// Seed 0x000000000000000000000000000000000000000023a8e79523c02100bd88400e => 0x00000000c1b78A4F3171fc53bD6A3CA05FceD326
// We want to start with 0x000000de1e80 which is 6 bytes
// Seed 0x00000000000000000000000000000000000000005d7cde2e4e4a52175e200216 => 0x000004De1E80EFb94a4383fFE3418f916027A251
// Seed 0x0000000000000000000000000000000000000000eab62839b3422a092c19bdab => 0x000000de1E803040Fba6B848D410a55FaB8B3256

// new inithash: 0xf911e320d18e7274491e7ab207bfff830e2926248f86c6a987668e8e72e1ed77

contract InitCodeHashTest is Test {
    DelegateRegistry reg;
    Singlesig sig;

    function setUp() public {
        reg = new DelegateRegistry();
        sig = new Singlesig(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215);
    }

    function getInitHash() public pure returns (bytes32) {
        // bytes memory bytecode = type(DelegateRegistry).creationCode;
        bytes memory initCode = abi.encodePacked(type(Singlesig).creationCode, abi.encode(address(0x6Ed7D526b020780f694f3c10Dfb25E1b134D3215)));

        return keccak256(abi.encodePacked(initCode));
    }

    function testInitHash() public {
        bytes32 initHash = getInitHash();
        emit log_bytes32(initHash);
    }
}

// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";
import {RegistryHashes} from "src/libraries/RegistryHashes.sol";

/// @dev Harness that exposes registry hashes library as contract
contract HashHarness {
    function decodeType(bytes32 hash) external pure returns (IDelegateRegistry.DelegationType) {
        return RegistryHashes.decodeType(hash);
    }

    function location(bytes32 hash) external pure returns (bytes32) {
        return RegistryHashes.location(hash);
    }

    function allHash(address from, bytes32 rights, address to) external pure returns (bytes32) {
        return RegistryHashes.allHash(from, rights, to);
    }

    function contractHash(address from, bytes32 rights, address to, address contract_) external pure returns (bytes32) {
        return RegistryHashes.contractHash(from, rights, to, contract_);
    }

    function erc721Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc721Hash(from, rights, to, tokenId, contract_);
    }

    function erc20Hash(address from, bytes32 rights, address to, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc20Hash(from, rights, to, contract_);
    }

    function erc1155Hash(address from, bytes32 rights, address to, uint256 tokenId, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc1155Hash(from, rights, to, tokenId, contract_);
    }

    function allLocation(address from, bytes32 rights, address to) external pure returns (bytes32) {
        return RegistryHashes.allLocation(from, rights, to);
    }

    function contractLocation(address from, bytes32 rights, address to, address contract_) external pure returns (bytes32) {
        return RegistryHashes.contractLocation(from, rights, to, contract_);
    }

    function erc721Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc721Location(from, rights, to, tokenId, contract_);
    }

    function erc20Location(address from, bytes32 rights, address to, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc20Location(from, rights, to, contract_);
    }

    function erc1155Location(address from, bytes32 rights, address to, uint256 tokenId, address contract_) external pure returns (bytes32) {
        return RegistryHashes.erc1155Location(from, rights, to, tokenId, contract_);
    }
}

contract HashBenchmark is Test {
    HashHarness hashHarness = new HashHarness();

    function testHashGas(address from, bytes32 rights, address to, uint256 tokenId, address contract_, bytes32 hash) public view {
        hashHarness.allHash(from, rights, to);
        hashHarness.allLocation(from, rights, to);
        hashHarness.contractHash(from, rights, to, contract_);
        hashHarness.contractLocation(from, rights, to, contract_);
        hashHarness.erc721Hash(from, rights, to, tokenId, contract_);
        hashHarness.erc721Location(from, rights, to, tokenId, contract_);
        hashHarness.erc20Hash(from, rights, to, contract_);
        hashHarness.erc20Location(from, rights, to, contract_);
        hashHarness.erc1155Hash(from, rights, to, tokenId, contract_);
        hashHarness.erc1155Location(from, rights, to, tokenId, contract_);
        hashHarness.location(hash);
        hashHarness.decodeType(0);
    }
}

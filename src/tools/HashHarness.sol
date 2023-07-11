// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {RegistryHashes} from "src/libraries/RegistryHashes.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

/// @dev Harness that exposes registry hashes library as contract
contract HashHarness {
    function encodeType(bytes32 hash, uint256 delegationType) external pure returns (bytes32) {
        return RegistryHashes.encodeType(hash, delegationType);
    }

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

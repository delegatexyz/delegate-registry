// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HashHarness} from "src/tools/HashHarness.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

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
        hashHarness.encodeType(hash, uint256(IDelegateRegistry.DelegationType.ALL));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import { DelegationRegistry } from "src/DelegationRegistry.sol";

contract DelegationRegistryTest is Test {

    DelegationRegistry reg;

    function setUp() public {
        reg = new DelegationRegistry();
    }

    function testApproveAndRevokeForAll(address vault, address delegate) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate, true);
        assertTrue(reg.checkDelegateForAll(delegate, vault));
        assertTrue(reg.checkDelegateForCollection(delegate, vault, address(0x0)));
        assertTrue(reg.checkDelegateForToken(delegate, vault, address(0x0), 0));
        // Revoke
        reg.delegateForAll(delegate, false);
        assertFalse(reg.checkDelegateForAll(delegate, vault));
    }

    function testApproveAndRevokeForCollection(address vault, address delegate, address collection) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForCollection(delegate, collection, true);
        assertTrue(reg.checkDelegateForCollection(delegate, vault, collection));
        assertTrue(reg.checkDelegateForToken(delegate, vault, collection, 0));
        // Revoke
        reg.delegateForCollection(delegate, collection, false);
        assertFalse(reg.checkDelegateForCollection(delegate, vault, collection));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, address collection, uint256 tokenId) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForToken(delegate, collection, tokenId, true);
        assertTrue(reg.checkDelegateForToken(delegate, vault, collection, tokenId));
        // Revoke
        reg.delegateForToken(delegate, collection, tokenId, false);
        assertFalse(reg.checkDelegateForToken(delegate, vault, collection, tokenId));
    }
}

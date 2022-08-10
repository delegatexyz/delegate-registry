// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import { DelegationRegistry } from "src/DelegationRegistry.sol";

contract DelegationRegistryTest is Test {

    DelegationRegistry reg;

    function setUp() public {
        reg = new DelegationRegistry();
    }

    function testApproveAndRevokeForAll(address vault, address delegate, bytes32 role) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate, role, true);
        assertTrue(reg.checkDelegateForAll(delegate, role, vault));
        assertTrue(reg.checkDelegateForCollection(delegate, role, vault, address(0x0)));
        assertTrue(reg.checkDelegateForToken(delegate, role, vault, address(0x0), 0));
        // Revoke
        reg.delegateForAll(delegate, role, false);
        assertFalse(reg.checkDelegateForAll(delegate, role, vault));
    }

    function testApproveAndRevokeForCollection(address vault, address delegate, bytes32 role, address collection) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForCollection(delegate, role, collection, true);
        assertTrue(reg.checkDelegateForCollection(delegate, role, vault, collection));
        assertTrue(reg.checkDelegateForToken(delegate, role, vault, collection, 0));
        // Revoke
        reg.delegateForCollection(delegate, role, collection, false);
        assertFalse(reg.checkDelegateForCollection(delegate, role, vault, collection));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, bytes32 role, address collection, uint256 tokenId) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForToken(delegate, role, collection, tokenId, true);
        assertTrue(reg.checkDelegateForToken(delegate, role, vault, collection, tokenId));
        // Revoke
        reg.delegateForToken(delegate, role, collection, tokenId, false);
        assertFalse(reg.checkDelegateForToken(delegate, role, vault, collection, tokenId));
    }
}

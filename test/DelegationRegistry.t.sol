// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { DelegationRegistry } from "src/DelegationRegistry.sol";
import { IDelegationRegistry } from "src/IDelegationRegistry.sol";

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
        assertTrue(reg.checkDelegateForContract(delegate, vault, address(0x0)));
        assertTrue(reg.checkDelegateForToken(delegate, vault, address(0x0), 0));
        // Revoke
        reg.delegateForAll(delegate, false);
        assertFalse(reg.checkDelegateForAll(delegate, vault));
    }

    function testApproveAndRevokeForContract(address vault, address delegate, address contract_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForContract(delegate, contract_, true);
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate, vault, contract_, 0));
        // Revoke
        reg.delegateForContract(delegate, contract_, false);
        assertFalse(reg.checkDelegateForContract(delegate, vault, contract_));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, address contract_, uint256 tokenId) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForToken(delegate, contract_, tokenId, true);
        assertTrue(reg.checkDelegateForToken(delegate, vault, contract_, tokenId));
        // Revoke
        reg.delegateForToken(delegate, contract_, tokenId, false);
        assertFalse(reg.checkDelegateForToken(delegate, vault, contract_, tokenId));
    }

    function testMultipleDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true);
        reg.delegateForAll(delegate1, true);
        // Read
        address[] memory delegates = reg.getDelegationsForAll(vault);
        assertEq(delegates.length, 2);
        assertEq(delegates[0], delegate0);
        assertEq(delegates[1], delegate1);
        // Remove
        reg.delegateForAll(delegate0, false);
        delegates = reg.getDelegationsForAll(vault);
        assertEq(delegates.length, 1);
    }

    function testRevokeDelegates(address vault0, address vault1, address delegate, address contract_, uint256 tokenId) public {
        vm.assume(delegate != vault0);
        vm.assume(vault0 != vault1);
        vm.startPrank(vault0);
        reg.delegateForAll(delegate, true);
        reg.delegateForContract(delegate, contract_, true);
        reg.delegateForToken(delegate, contract_, tokenId, true);
        vm.stopPrank();
        vm.startPrank(vault1);
        reg.delegateForAll(delegate, true);
        reg.delegateForContract(delegate, contract_, true);
        reg.delegateForToken(delegate, contract_, tokenId, true);
        vm.stopPrank();
        // Revoke delegates for vault0
        vm.startPrank(vault0);
        reg.revokeAllDelegates();
        vm.stopPrank();
        // Read
        address[] memory vault0DelegatesForAll = reg.getDelegationsForAll(vault0);
        assertEq(vault0DelegatesForAll.length, 0);
        address[] memory vault1DelegatesForAll = reg.getDelegationsForAll(vault1);
        assertEq(vault1DelegatesForAll.length, 1);
        address[] memory vault0DelegatesForContract = reg.getDelegationsForContract(vault0, contract_);
        assertEq(vault0DelegatesForContract.length, 0);
        address[] memory vault1DelegatesForContract = reg.getDelegationsForContract(vault1, contract_);
        assertEq(vault1DelegatesForContract.length, 1);
        address[] memory vault0DelegatesForToken = reg.getDelegationsForToken(vault0, contract_, tokenId);
        assertEq(vault0DelegatesForToken.length, 0);
        address[] memory vault1DelegatesForToken = reg.getDelegationsForToken(vault1, contract_, tokenId);
        assertEq(vault1DelegatesForToken.length, 1);

        assertFalse(reg.checkDelegateForAll(delegate, vault0));
        assertTrue(reg.checkDelegateForAll(delegate, vault1));
        assertFalse(reg.checkDelegateForContract(delegate, vault0, contract_));
        assertTrue(reg.checkDelegateForContract(delegate, vault1, contract_));
        assertFalse(reg.checkDelegateForToken(delegate, vault0, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate, vault1, contract_, tokenId));
    }

    function testRevokeDelegate(address vault, address delegate0, address delegate1, address contract_, uint256 tokenId) public {
        vm.assume(vault != delegate0);
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract_, true);
        reg.delegateForToken(delegate0, contract_, tokenId, true);
        reg.delegateForAll(delegate1, true);
        reg.delegateForContract(delegate1, contract_, true);
        reg.delegateForToken(delegate1, contract_, tokenId, true);
        
        // Revoke delegate0
        reg.revokeDelegate(delegate0);
        vm.stopPrank();
        // Read
        address[] memory vaultDelegatesForAll = reg.getDelegationsForAll(vault);
        assertEq(vaultDelegatesForAll.length, 1);
        assertEq(vaultDelegatesForAll[0], delegate1);
        address[] memory vaultDelegatesForContract = reg.getDelegationsForContract(vault, contract_);
        assertEq(vaultDelegatesForContract.length, 1);
        assertEq(vaultDelegatesForContract[0], delegate1);
        address[] memory vaultDelegatesForToken = reg.getDelegationsForToken(vault, contract_, tokenId);
        assertEq(vaultDelegatesForToken.length, 1);
        assertEq(vaultDelegatesForToken[0], delegate1);

        assertFalse(reg.checkDelegateForAll(delegate0, vault));
        assertTrue(reg.checkDelegateForAll(delegate1, vault));
        assertFalse(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertFalse(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));
    }

    function testRevokeSelf(address vault, address delegate0, address delegate1, address contract_, uint256 tokenId) public {
        vm.assume(vault != delegate0);
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract_, true);
        reg.delegateForToken(delegate0, contract_, tokenId, true);
        reg.delegateForAll(delegate1, true);
        reg.delegateForContract(delegate1, contract_, true);
        reg.delegateForToken(delegate1, contract_, tokenId, true);
        
        // delegate 0 revoke self from being a delegate for vault
        changePrank(delegate0);
        reg.revokeSelf(vault);
        vm.stopPrank();
        // Read
        address[] memory vaultDelegatesForAll = reg.getDelegationsForAll(vault);
        assertEq(vaultDelegatesForAll.length, 1);
        assertEq(vaultDelegatesForAll[0], delegate1);
        address[] memory vaultDelegatesForContract = reg.getDelegationsForContract(vault, contract_);
        assertEq(vaultDelegatesForContract.length, 1);
        assertEq(vaultDelegatesForContract[0], delegate1);
        address[] memory vaultDelegatesForToken = reg.getDelegationsForToken(vault, contract_, tokenId);
        assertEq(vaultDelegatesForToken.length, 1);
        assertEq(vaultDelegatesForToken[0], delegate1);

        assertFalse(reg.checkDelegateForAll(delegate0, vault));
        assertTrue(reg.checkDelegateForAll(delegate1, vault));
        assertFalse(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertFalse(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));
    }

    function testDelegateEnumeration(address vault0, address vault1, address delegate0, address delegate1, address contract0, address contract1, uint256 tokenId0, uint256 tokenId1) public {
        vm.assume(vault0 != vault1);
        vm.assume(vault0 != delegate0);
        vm.assume(vault0 != delegate1);
        vm.assume(vault1 != delegate0);
        vm.assume(vault1 != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != contract1);
        vm.assume(tokenId0 != tokenId1);
        vm.startPrank(vault0);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract0, true);
        reg.delegateForToken(delegate0, contract1, tokenId1, true);
        reg.delegateForAll(delegate1, true);
        reg.delegateForContract(delegate1, contract0, true);
        reg.delegateForToken(delegate1, contract1, tokenId1, true);
        vm.stopPrank();

        vm.startPrank(vault1);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract1, true);
        reg.delegateForToken(delegate0, contract0, tokenId0, true);

        // Read
        IDelegationRegistry.DelegationInfo[] memory info;
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 6);

        // Revoke
        reg.delegateForAll(delegate0, false);
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 5);
        reg.delegateForContract(delegate0, contract1, false);
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 4);
        reg.delegateForToken(delegate0, contract0, tokenId0, false);
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 3);

        // Grant again
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract1, true);
        reg.delegateForToken(delegate0, contract0, tokenId0, true);

        // vault1 revoke delegate0
        vm.stopPrank();
        vm.startPrank(vault0);
        reg.revokeDelegate(delegate0);
        vm.stopPrank();

        // Remaining delegations should all be related to vault1
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 3);
        assertEq(info[0].vault, vault1);
        assertEq(info[1].vault, vault1);
        assertEq(info[2].vault, vault1);
        info = reg.getDelegationsForDelegate(delegate1);
        assertEq(info.length, 3);
        assertEq(info[0].vault, vault0);
        assertEq(info[1].vault, vault0);
        assertEq(info[2].vault, vault0);

        // vault1 revokes all delegates
        vm.startPrank(vault1);
        reg.revokeAllDelegates();
        vm.stopPrank();

        // delegate0 has no more delegations, delegate1 remains
        info = reg.getDelegationsForDelegate(delegate0);
        assertEq(info.length, 0);
        info = reg.getDelegationsForDelegate(delegate1);
        assertEq(info.length, 3);
        assertEq(info[0].vault, vault0);
        assertEq(info[1].vault, vault0);
        assertEq(info[2].vault, vault0);

    }
}

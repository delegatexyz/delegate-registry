// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { DelegationRegistry } from "src/DelegationRegistry.sol";

contract DelegationRegistryTest is Test {

    DelegationRegistry reg;

    function setUp() public {
        reg = new DelegationRegistry();
    }

    function testApproveAndRevokeForAll(address vault, address delegate) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate, 1234);
        assertTrue(reg.checkDelegateForAll(delegate, vault));
        assertTrue(reg.checkDelegateForContract(delegate, vault, address(0x0)));
        assertTrue(reg.checkDelegateForToken(delegate, vault, address(0x0), 0));
        // Revoke
        reg.revokeDelegate(delegate);
        assertFalse(reg.checkDelegateForAll(delegate, vault));
    }

    function testApproveAndRevokeForContract(address vault, address delegate, address contract_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForContract(delegate, contract_, 1234);
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate, vault, contract_, 0));
        // Revoke
        reg.revokeForContract(delegate, contract_);
        assertFalse(reg.checkDelegateForContract(delegate, vault, contract_));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, address contract_, uint256 tokenId) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForToken(delegate, contract_, tokenId, 1234);
        assertTrue(reg.checkDelegateForToken(delegate, vault, contract_, tokenId));
        // Revoke
        reg.revokeForToken(delegate, contract_, tokenId);
        assertFalse(reg.checkDelegateForToken(delegate, vault, contract_, tokenId));
    }

    function testMultipleDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, 1234);
        reg.delegateForAll(delegate1, 1234);
        // Read
        address[] memory delegates = reg.getDelegationsForAll(vault);
        assertEq(delegates.length, 2);
        assertEq(delegates[0], delegate0);
        assertEq(delegates[1], delegate1);
        // Remove
        reg.revokeDelegate(delegate0);
        delegates = reg.getDelegationsForAll(vault);
        assertEq(delegates.length, 1);
    }

    function testRevokeDelegates(address vault0, address vault1, address delegate, address contract_, uint256 tokenId) public {
        vm.assume(delegate != vault0);
        vm.assume(vault0 != vault1);
        vm.startPrank(vault0);
        reg.delegateForAll(delegate, 1234);
        reg.delegateForContract(delegate, contract_, 1234);
        reg.delegateForToken(delegate, contract_, tokenId, 1234);
        vm.stopPrank();
        vm.startPrank(vault1);
        reg.delegateForAll(delegate, 1234);
        reg.delegateForContract(delegate, contract_, 1234);
        reg.delegateForToken(delegate, contract_, tokenId, 1234);
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
        reg.delegateForAll(delegate0, 1234);
        reg.delegateForContract(delegate0, contract_, 1234);
        reg.delegateForToken(delegate0, contract_, tokenId, 1234);
        reg.delegateForAll(delegate1, 1234);
        reg.delegateForContract(delegate1, contract_, 1234);
        reg.delegateForToken(delegate1, contract_, tokenId, 1234);
        
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

    function testApproveAndExpireForAll(address vault, address delegate0, address delegate1, address contract_, uint256 tokenId) public {
        vm.assume(vault != delegate0);
        vm.assume(delegate0 != delegate1);
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, 1234);
        assertTrue(reg.checkDelegateForAll(delegate0, vault));
        assertTrue(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        reg.delegateForAll(delegate1, 5678);
        assertTrue(reg.checkDelegateForAll(delegate1, vault));
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));

        // Expire
        vm.warp(4321);

        // Read
        address[] memory vaultDelegatesForAll = reg.getDelegationsForAll(vault);
        assertEq(vaultDelegatesForAll.length, 1);
        assertEq(vaultDelegatesForAll[0], delegate1);

        assertFalse(reg.checkDelegateForAll(delegate0, vault));
        assertTrue(reg.checkDelegateForAll(delegate1, vault));
        assertFalse(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertFalse(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));
    }

    function testApproveAndExpireForContract(address vault, address delegate0, address delegate1, address contract_, uint256 tokenId) public {
        vm.assume(vault != delegate0);
        vm.assume(delegate0 != delegate1);
        // Approve
        vm.startPrank(vault);
        reg.delegateForContract(delegate0, contract_, 1234);
        assertTrue(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        reg.delegateForContract(delegate1, contract_, 5678);
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));

        // Expire
        vm.warp(4321);

        // Read
        address[] memory vaultDelegatesForContract = reg.getDelegationsForContract(vault, contract_);
        assertEq(vaultDelegatesForContract.length, 1);
        assertEq(vaultDelegatesForContract[0], delegate1);

        assertFalse(reg.checkDelegateForContract(delegate0, vault, contract_));
        assertTrue(reg.checkDelegateForContract(delegate1, vault, contract_));
        assertFalse(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));
    }

    function testApproveAndExpireForToken(address vault, address delegate0, address delegate1, address contract_, uint256 tokenId) public {
        vm.assume(vault != delegate0);
        vm.assume(delegate0 != delegate1);
        // Approve
        vm.startPrank(vault);
        reg.delegateForToken(delegate0, contract_, tokenId, 1234);
        assertTrue(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        reg.delegateForToken(delegate1, contract_, tokenId, 5678);
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));

        // Expire
        vm.warp(4321);

        // Read
        address[] memory vaultDelegatesForToken = reg.getDelegationsForToken(vault, contract_, tokenId);
        assertEq(vaultDelegatesForToken.length, 1);
        assertEq(vaultDelegatesForToken[0], delegate1);

        assertFalse(reg.checkDelegateForToken(delegate0, vault, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate1, vault, contract_, tokenId));
    }
}

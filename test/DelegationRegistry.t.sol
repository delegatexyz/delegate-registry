// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegationRegistry} from "src/DelegationRegistry.sol";
import {IDelegationRegistry} from "src/IDelegationRegistry.sol";

contract DelegationRegistryTest is Test {
    DelegationRegistry reg;

    function setUp() public {
        reg = new DelegationRegistry();
    }

    function getInitHash() public pure returns (bytes32) {
        bytes memory bytecode = type(DelegationRegistry).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }

    function testInitHash() public {
        bytes32 initHash = getInitHash();
        emit log_bytes32(initHash);
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
        IDelegationRegistry.DelegationInfo[] memory info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 2);
        assertEq(info[0].vault, vault);
        assertEq(info[0].delegate, delegate0);
        assertEq(info[1].vault, vault);
        assertEq(info[1].delegate, delegate1);
        // Remove
        reg.delegateForAll(delegate0, false);
        info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 1);
    }

    function testBatchDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        IDelegationRegistry.DelegationInfo[] memory info = new IDelegationRegistry.DelegationInfo[](2);
        info[0] = IDelegationRegistry.DelegationInfo({
            type_: IDelegationRegistry.DelegationType.ALL,
            vault: vault,
            delegate: delegate0,
            contract_: address(0),
            tokenId: 0
        });
        info[1] = IDelegationRegistry.DelegationInfo({
            type_: IDelegationRegistry.DelegationType.ALL,
            vault: vault,
            delegate: delegate1,
            contract_: address(0),
            tokenId: 0
        });
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[0] = true;
        reg.batchDelegate(info, values);

        IDelegationRegistry.DelegationInfo[] memory delegations = reg.getDelegationsForVault(vault);
        assertEq(info.length, 2);
        assertEq(info[0].vault, vault);
        assertEq(info[1].vault, vault);
        assertEq(info[0].delegate, delegate0);
        assertEq(info[1].delegate, delegate1);
        assertTrue(info[0].type_ == IDelegationRegistry.DelegationType.ALL);
        assertTrue(info[1].type_ == IDelegationRegistry.DelegationType.ALL);
    }

    function testRevokeAllDelegates(
        address vault0,
        address vault1,
        address delegate,
        address contract_,
        uint256 tokenId
    ) public {
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
        IDelegationRegistry.DelegationInfo[] memory info0 = reg.getDelegationsForVault(vault0);
        assertEq(info0.length, 0);
        IDelegationRegistry.DelegationInfo[] memory info1 = reg.getDelegationsForVault(vault1);
        assertEq(info1.length, 3);
        // TODO: Add helper methods that filter by contract or token and get proper enumeration lengths there

        assertFalse(reg.checkDelegateForAll(delegate, vault0));
        assertTrue(reg.checkDelegateForAll(delegate, vault1));
        assertFalse(reg.checkDelegateForContract(delegate, vault0, contract_));
        assertTrue(reg.checkDelegateForContract(delegate, vault1, contract_));
        assertFalse(reg.checkDelegateForToken(delegate, vault0, contract_, tokenId));
        assertTrue(reg.checkDelegateForToken(delegate, vault1, contract_, tokenId));
    }

    function testDelegateEnumeration(
        address vault0,
        address vault1,
        address delegate0,
        address delegate1,
        address contract0,
        address contract1,
        uint256 tokenId0,
        uint256 tokenId1
    ) public {
        vm.assume(vault0 != vault1);
        vm.assume(vault0 != delegate0);
        vm.assume(vault0 != delegate1);
        vm.assume(vault1 != delegate0);
        vm.assume(vault1 != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != contract1);
        vm.assume(tokenId0 != tokenId1);
        vm.assume(contract0 != address(0x0));
        vm.assume(contract1 != address(0x0));
        vm.assume(tokenId0 != 0);
        vm.assume(tokenId1 != 0);

        // vault0 delegates all three tiers to delegate0, and all three tiers to delegate1
        vm.startPrank(vault0);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract0, true);
        reg.delegateForToken(delegate0, contract0, tokenId0, true);
        reg.delegateForAll(delegate1, true);
        reg.delegateForContract(delegate1, contract1, true);
        reg.delegateForToken(delegate1, contract1, tokenId1, true);

        // vault1 delegates all three tiers to delegate0
        changePrank(vault1);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract0, true);
        reg.delegateForToken(delegate0, contract0, tokenId0, true);

        // vault0 revokes all three tiers for delegate0, check incremental decrease in delegate enumerations
        changePrank(vault0);
        // check six in total, three from vault0 and three from vault1
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 6);
        reg.delegateForAll(delegate0, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 5);
        reg.delegateForContract(delegate0, contract0, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 4);
        reg.delegateForToken(delegate0, contract0, tokenId0, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 3);

        // vault0 re-delegates to delegate0
        changePrank(vault0);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract0, true);
        reg.delegateForToken(delegate0, contract0, tokenId0, true);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 6);
        assertEq(reg.getDelegationsForDelegate(delegate1).length, 3);
    }

    function testVaultEnumerations(
        address vault,
        address delegate0,
        address delegate1,
        address contract0,
        address contract1,
        uint256 tokenId
    ) public {
        vm.assume(vault != delegate0);
        vm.assume(vault != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != contract1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true);
        reg.delegateForContract(delegate0, contract0, true);
        reg.delegateForToken(delegate0, contract1, tokenId, true);
        reg.delegateForAll(delegate1, true);
        reg.delegateForContract(delegate1, contract0, true);

        // Read
        IDelegationRegistry.DelegationInfo[] memory vaultDelegations;
        vaultDelegations = reg.getDelegationsForVault(vault);
        assertEq(vaultDelegations.length, 5);
        assertTrue(vaultDelegations[1].type_ == IDelegationRegistry.DelegationType.CONTRACT);

        // Revoke all
        reg.revokeAllDelegates();
        assertEq(reg.getDelegationsForVault(vault).length, 0);
    }
}

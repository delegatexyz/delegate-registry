// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegateRegistry as Registry} from "src/DelegateRegistry.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryHarness as Harness} from "src/tools/RegistryHarness.sol";

contract DelegateAllTest is Test {
    Registry public registry;
    Harness public harness;

    function setUp() public {
        harness = new Harness();
        registry = new Registry();
    }

    // Tests delegateAll case with non-default rights
    function testDelegateAllSpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        bytes32 rights,
        bytes32 fRights,
        address dContract,
        uint256 dTokenId
    ) public {
        vm.assume(rights != "");
        _testDelegateAll(vault, fVault, delegate, fDelegate, rights, fRights, dContract, dTokenId);
    }

    // Tests delegateAll case with default rights
    function testDelegateAllDefault(address vault, address fVault, address delegate, address fDelegate, bytes32 fRights, address dContract, uint256 dTokenId)
        public
    {
        bytes32 rights = "";
        _testDelegateAll(vault, fVault, delegate, fDelegate, rights, fRights, dContract, dTokenId);
    }

    function _testDelegateAll(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        bytes32 rights,
        bytes32 fRights,
        address dContract,
        uint256 dTokenId
    ) internal {
        registry = new Registry();
        bool enable = uint256(keccak256(abi.encode(vault, fVault, delegate, fDelegate, rights, fRights, dContract, dTokenId))) % 2 == 1;
        bool multicall = uint256(keccak256(abi.encode(dTokenId, dContract, fRights, rights, fDelegate, delegate, fVault))) % 2 == 1;
        vm.assume(vault > address(1) && fVault > address(1));
        vm.assume(vault != fVault && delegate != fDelegate && rights != fRights);
        vm.assume(vault != delegate && vault != fDelegate);
        vm.assume(fVault != delegate && fVault != fDelegate);
        vm.assume(dContract != vault && dContract != fVault && dContract != delegate && dContract != fDelegate);
        // Create delegation
        vm.startPrank(vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateAll.selector, delegate, rights, enable);
        if (multicall) registry.multicall(batchData);
        else registry.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        // Check consumables and read
        _checkConsumable(vault, fVault, delegate, fDelegate, rights, fRights, dContract, dTokenId, enable);
        _checkRead(vault, fVault, delegate, fDelegate, rights, enable);
        // Revoke and check logic again
        vm.startPrank(vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateAll.selector, delegate, rights, false);
        if (multicall) registry.multicall(batchData);
        else registry.delegateAll(delegate, rights, false);
        vm.stopPrank();
        _checkConsumable(vault, fVault, delegate, fDelegate, rights, fRights, dContract, dTokenId, false);
        _checkRead(vault, fVault, delegate, fDelegate, rights, false);
    }

    function _checkConsumable(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        bytes32 rights,
        bytes32 fRights,
        address dContract,
        uint256 dTokenId,
        bool enable
    ) internal {
        // Check logic outcomes of checkDelegateForAll
        assertTrue(registry.checkDelegateForAll(delegate, vault, rights) == enable);
        if (rights == "") assertTrue(registry.checkDelegateForAll(delegate, vault, fRights) == enable);
        else assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
        assertFalse(registry.checkDelegateForAll(delegate, fVault, fRights));
        assertFalse(registry.checkDelegateForAll(delegate, fVault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, vault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, fVault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, vault, fRights));
        assertFalse(registry.checkDelegateForAll(fDelegate, fVault, fRights));
        // Check logic outcomes of checkDelegateForContract
        assertTrue(registry.checkDelegateForContract(delegate, vault, dContract, rights) == enable);
        if (rights == "") assertTrue(registry.checkDelegateForContract(delegate, vault, dContract, fRights) == enable);
        else assertFalse(registry.checkDelegateForContract(delegate, vault, dContract, fRights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, dContract, fRights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, dContract, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, dContract, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, dContract, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, dContract, fRights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, dContract, fRights));
        // Check logic outcomes of checkDelegateForERC721
        assertTrue(registry.checkDelegateForERC721(delegate, vault, dContract, dTokenId, rights) == enable);
        if (rights == "") {
            assertTrue(registry.checkDelegateForERC721(delegate, vault, dContract, dTokenId, fRights) == enable);
        } else {
            assertFalse(registry.checkDelegateForERC721(delegate, vault, dContract, dTokenId, fRights));
        }
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, dContract, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, dContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, dContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, dContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, dContract, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, dContract, dTokenId, fRights));
        // Check logic outcomes of checkDelegateForERC20
        assertTrue((registry.checkDelegateForERC20(delegate, vault, dContract, rights) == type(uint256).max) == enable);
        if (rights == "") {
            assertTrue((registry.checkDelegateForERC20(delegate, vault, dContract, fRights) == type(uint256).max) == enable);
        } else {
            assertEq(registry.checkDelegateForERC20(delegate, vault, dContract, fRights), 0);
        }
        assertEq(registry.checkDelegateForERC20(delegate, fVault, dContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, fVault, dContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, dContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, dContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, dContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, dContract, fRights), 0);
        // Check logic outcomes of checkDelegateForERC1155
        assertTrue((registry.checkDelegateForERC1155(delegate, vault, dContract, dTokenId, rights) == type(uint256).max) == enable);
        if (rights == "") {
            assertTrue((registry.checkDelegateForERC1155(delegate, vault, dContract, dTokenId, fRights) == type(uint256).max) == enable);
        } else {
            assertEq(registry.checkDelegateForERC1155(delegate, vault, dContract, dTokenId, fRights), 0);
        }
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, dContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, dContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, dContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, dContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, dContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, dContract, dTokenId, fRights), 0);
    }

    function _checkRead(address vault, address fVault, address delegate, address fDelegate, bytes32 rights, bool enable) internal {
        // Check outcomes of getDelegationsForDelegate
        assertEq(registry.getDelegationsForDelegate(delegate).length == 1, enable);
        if (enable) _checkDelegation(registry.getDelegationsForDelegate(delegate)[0], delegate, vault, rights, enable);
        assertEq(registry.getDelegationsForDelegate(vault).length, 0);
        assertEq(registry.getDelegationsForDelegate(fVault).length, 0);
        assertEq(registry.getDelegationsForDelegate(fDelegate).length, 0);
        // Check outcomes of getDelegationsForVault
        assertEq(registry.getDelegationsForVault(vault).length == 1, enable);
        if (enable) _checkDelegation(registry.getDelegationsForDelegate(delegate)[0], delegate, vault, rights, enable);
        assertEq(registry.getDelegationsForVault(fVault).length, 0);
        assertEq(registry.getDelegationsForVault(delegate).length, 0);
        assertEq(registry.getDelegationsForVault(fDelegate).length, 0);
        // Check outcomes of getDelegationHashesForDelegate
        assertEq(registry.getDelegationHashesForDelegate(delegate).length == 1, enable);
        if (enable) {
            assertEq(registry.getDelegationHashesForDelegate(delegate)[0], harness.exposed_computeDelegationHashForAll(delegate, rights, vault));
        }
        assertEq(registry.getDelegationHashesForDelegate(vault).length, 0);
        assertEq(registry.getDelegationHashesForDelegate(fVault).length, 0);
        assertEq(registry.getDelegationHashesForDelegate(fDelegate).length, 0);
        // Check outcomes of getDelegationHashesForVault
        assertEq(registry.getDelegationHashesForVault(vault).length == 1, enable);
        if (enable) {
            assertEq(registry.getDelegationHashesForVault(vault)[0], harness.exposed_computeDelegationHashForAll(delegate, rights, vault));
        }
        assertEq(registry.getDelegationHashesForVault(fVault).length, 0);
        assertEq(registry.getDelegationHashesForVault(delegate).length, 0);
        assertEq(registry.getDelegationHashesForVault(fDelegate).length, 0);
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = harness.exposed_computeDelegationHashForAll(delegate, rights, vault);
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0], delegate, vault, rights, enable);
    }

    function _checkDelegation(IRegistry.Delegation memory delegation, address delegate, address vault, bytes32 rights, bool enable) internal {
        if (enable) {
            assertEq(uint256(delegation.type_), uint256(IRegistry.DelegationType.ALL));
            assertEq(delegation.delegate, delegate);
            assertEq(delegation.vault, vault);
            assertEq(delegation.rights, rights);
            assertEq(delegation.contract_, address(0));
            assertEq(delegation.tokenId, 0);
            assertEq(delegation.amount, 0);
        } else {
            assertEq(uint256(delegation.type_), uint256(IRegistry.DelegationType.ALL));
            assertEq(delegation.delegate, address(0));
            assertLe(uint160(delegation.vault), uint160(address(1)));
            assertEq(delegation.rights, "");
            assertEq(delegation.contract_, address(0));
            assertEq(delegation.tokenId, 0);
            assertEq(delegation.amount, 0);
        }
    }
}

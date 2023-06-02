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

    // Tests delegateContract case with non-default rights
    function testDelegateContractSpecificRights(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 rights,
        bytes32 fRights,
        uint256 dTokenId
    ) public {
        vm.assume(rights != "");
        _testDelegateContract(vault, fVault, delegate, fDelegate, contract_, fContract, rights, fRights, dTokenId);
    }

    // Tests delegateContract case with default rights
    function testDelegateContractDefault(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 fRights,
        uint256 dTokenId
    ) public {
        bytes32 rights = "";
        _testDelegateContract(vault, fVault, delegate, fDelegate, contract_, fContract, rights, fRights, dTokenId);
    }

    function _testDelegateContract(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 rights,
        bytes32 fRights,
        uint256 dTokenId
    ) internal {
        registry = new Registry();
        bool enable = uint256(keccak256(abi.encode(vault, fVault, delegate, fDelegate, rights, fRights, fContract, dTokenId))) % 2 == 1;
        bool multicall = uint256(keccak256(abi.encode(dTokenId, fContract, fRights, rights, fDelegate, delegate))) % 2 == 1;
        vm.assume(vault > address(1) && fVault > address(1));
        vm.assume(vault != fVault && vault != delegate && vault != fDelegate && vault != contract_ && vault != fContract);
        vm.assume(fVault != delegate && fVault != fDelegate && fVault != contract_ && fVault != fContract);
        vm.assume(delegate != fDelegate && delegate != contract_ && delegate != fContract);
        vm.assume(fDelegate != contract_ && fDelegate != fContract);
        vm.assume(contract_ != fContract);
        vm.assume(rights != fRights);
        // Create delegation
        vm.startPrank(vault);
        bytes[] memory batchData = new bytes[](1);
        batchData[0] = abi.encodeWithSelector(Registry.delegateContract.selector, delegate, contract_, rights, enable);
        if (multicall) registry.multicall(batchData);
        else registry.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        // Check consumables and read
        _checkConsumable(vault, fVault, delegate, fDelegate, contract_, fContract, rights, fRights, dTokenId, enable);
        _checkRead(vault, fVault, delegate, fDelegate, contract_, rights, enable);
        // Revoke and check logic again
        vm.startPrank(vault);
        batchData[0] = abi.encodeWithSelector(Registry.delegateContract.selector, delegate, contract_, rights, false);
        if (multicall) registry.multicall(batchData);
        else registry.delegateContract(delegate, contract_, rights, false);
        vm.stopPrank();
        _checkConsumable(vault, fVault, delegate, fDelegate, contract_, fContract, rights, fRights, dTokenId, false);
        _checkRead(vault, fVault, delegate, fDelegate, contract_, rights, false);
    }

    function _checkConsumable(
        address vault,
        address fVault,
        address delegate,
        address fDelegate,
        address contract_,
        address fContract,
        bytes32 rights,
        bytes32 fRights,
        uint256 dTokenId,
        bool enable
    ) internal {
        // Check logic outcomes of checkDelegateForAll
        assertFalse(registry.checkDelegateForAll(delegate, vault, rights));
        assertFalse(registry.checkDelegateForAll(delegate, vault, fRights));
        assertFalse(registry.checkDelegateForAll(delegate, fVault, fRights));
        assertFalse(registry.checkDelegateForAll(delegate, fVault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, vault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, fVault, rights));
        assertFalse(registry.checkDelegateForAll(fDelegate, vault, fRights));
        assertFalse(registry.checkDelegateForAll(fDelegate, fVault, fRights));
        // Check logic outcomes of checkDelegateForContract
        assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, rights) == enable);
        if (rights == "") {
            assertTrue(registry.checkDelegateForContract(delegate, vault, contract_, fRights) == enable);
        } else {
            assertFalse(registry.checkDelegateForContract(delegate, vault, contract_, fRights));
        }
        assertFalse(registry.checkDelegateForContract(delegate, vault, fContract, rights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, contract_, rights));
        assertFalse(registry.checkDelegateForContract(delegate, vault, fContract, fRights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, fContract, rights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, contract_, fRights));
        assertFalse(registry.checkDelegateForContract(delegate, fVault, fContract, fRights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, contract_, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, contract_, fRights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, fContract, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, contract_, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, vault, fContract, fRights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, fContract, rights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, contract_, fRights));
        assertFalse(registry.checkDelegateForContract(fDelegate, fVault, fContract, fRights));
        // Check logic outcomes of checkDelegateForERC721
        assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, dTokenId, rights) == enable);
        if (rights == "") {
            assertTrue(registry.checkDelegateForERC721(delegate, vault, contract_, dTokenId, fRights) == enable);
        } else {
            assertFalse(registry.checkDelegateForERC721(delegate, vault, contract_, dTokenId, fRights));
        }
        assertFalse(registry.checkDelegateForERC721(delegate, vault, fContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, contract_, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(delegate, vault, fContract, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, fContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, contract_, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(delegate, fVault, fContract, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, contract_, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, contract_, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, fContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, contract_, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, vault, fContract, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, fContract, dTokenId, rights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, contract_, dTokenId, fRights));
        assertFalse(registry.checkDelegateForERC721(fDelegate, fVault, fContract, dTokenId, fRights));
        // Check logic outcomes of checkDelegateForERC20
        assertTrue((registry.checkDelegateForERC20(delegate, vault, contract_, rights) == type(uint256).max) == enable);
        if (rights == "") {
            assertTrue((registry.checkDelegateForERC20(delegate, vault, contract_, fRights) == type(uint256).max) == enable);
        } else {
            assertEq(registry.checkDelegateForERC20(delegate, vault, contract_, fRights), 0);
        }
        assertEq(registry.checkDelegateForERC20(delegate, vault, fContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, fVault, contract_, rights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, vault, fContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, fVault, fContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, fVault, fContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(delegate, fVault, fContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, contract_, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, contract_, fRights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, fContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, contract_, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, vault, fContract, fRights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, fContract, rights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, contract_, fRights), 0);
        assertEq(registry.checkDelegateForERC20(fDelegate, fVault, fContract, fRights), 0);
        // Check logic outcomes of checkDelegateForERC1155
        assertTrue((registry.checkDelegateForERC1155(delegate, vault, contract_, dTokenId, rights) == type(uint256).max) == enable);
        if (rights == "") {
            assertTrue((registry.checkDelegateForERC1155(delegate, vault, contract_, dTokenId, fRights) == type(uint256).max) == enable);
        } else {
            assertEq(registry.checkDelegateForERC1155(delegate, vault, contract_, dTokenId, fRights), 0);
        }
        assertEq(registry.checkDelegateForERC1155(delegate, vault, fContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, contract_, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, vault, fContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, fContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, fContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(delegate, fVault, fContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, contract_, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, contract_, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, fContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, contract_, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, vault, fContract, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, fContract, dTokenId, rights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, contract_, dTokenId, fRights), 0);
        assertEq(registry.checkDelegateForERC1155(fDelegate, fVault, fContract, dTokenId, fRights), 0);
    }

    function _checkRead(address vault, address fVault, address delegate, address fDelegate, address contract_, bytes32 rights, bool enable) internal {
        // Check outcomes of getDelegationsForDelegate
        assertEq(registry.getDelegationsForDelegate(delegate).length == 1, enable);
        if (enable) _checkDelegation(registry.getDelegationsForDelegate(delegate)[0], delegate, vault, contract_, rights, enable);
        assertEq(registry.getDelegationsForDelegate(vault).length, 0);
        assertEq(registry.getDelegationsForDelegate(fVault).length, 0);
        assertEq(registry.getDelegationsForDelegate(fDelegate).length, 0);
        // Check outcomes of getDelegationsForVault
        assertEq(registry.getDelegationsForVault(vault).length == 1, enable);
        if (enable) _checkDelegation(registry.getDelegationsForDelegate(delegate)[0], delegate, vault, contract_, rights, enable);
        assertEq(registry.getDelegationsForVault(fVault).length, 0);
        assertEq(registry.getDelegationsForVault(delegate).length, 0);
        assertEq(registry.getDelegationsForVault(fDelegate).length, 0);
        // Check outcomes of getDelegationHashesForDelegate
        assertEq(registry.getDelegationHashesForDelegate(delegate).length == 1, enable);
        if (enable) {
            assertEq(registry.getDelegationHashesForDelegate(delegate)[0], harness.exposed_computeDelegationHashForContract(contract_, delegate, rights, vault));
        }
        assertEq(registry.getDelegationHashesForDelegate(vault).length, 0);
        assertEq(registry.getDelegationHashesForDelegate(fVault).length, 0);
        assertEq(registry.getDelegationHashesForDelegate(fDelegate).length, 0);
        // Check outcomes of getDelegationHashesForVault
        assertEq(registry.getDelegationHashesForVault(vault).length == 1, enable);
        if (enable) {
            assertEq(registry.getDelegationHashesForVault(vault)[0], harness.exposed_computeDelegationHashForContract(contract_, delegate, rights, vault));
        }
        assertEq(registry.getDelegationHashesForVault(fVault).length, 0);
        assertEq(registry.getDelegationHashesForVault(delegate).length, 0);
        assertEq(registry.getDelegationHashesForVault(fDelegate).length, 0);
        // Check outcomes of getDelegationsFromHashes
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = harness.exposed_computeDelegationHashForContract(contract_, delegate, rights, vault);
        assertEq(registry.getDelegationsFromHashes(hashes).length, 1);
        _checkDelegation(registry.getDelegationsFromHashes(hashes)[0], delegate, vault, contract_, rights, enable);
    }

    function _checkDelegation(IRegistry.Delegation memory delegation, address delegate, address vault, address contract_, bytes32 rights, bool enable)
        internal
    {
        if (enable) {
            assertEq(uint256(delegation.type_), uint256(IRegistry.DelegationType.CONTRACT));
            assertEq(delegation.delegate, delegate);
            assertEq(delegation.vault, vault);
            assertEq(delegation.rights, rights);
            assertEq(delegation.contract_, contract_);
            assertEq(delegation.tokenId, 0);
            assertEq(delegation.amount, 0);
        } else {
            assertEq(uint256(delegation.type_), uint256(IRegistry.DelegationType.CONTRACT));
            assertEq(delegation.delegate, address(0));
            assertLe(uint160(delegation.vault), uint160(address(1)));
            assertEq(delegation.rights, "");
            assertEq(delegation.contract_, address(0));
            assertEq(delegation.tokenId, 0);
            assertEq(delegation.amount, 0);
        }
    }
}

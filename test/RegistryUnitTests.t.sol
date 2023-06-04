// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryHarness as Harness} from "src/tools/RegistryHarness.sol";

contract RegistryUnitTests is Test {
    Harness public harness;

    enum StoragePositions {
        delegate,
        vault,
        rights,
        contract_,
        tokenId,
        amount
    }

    function setUp() public {
        harness = new Harness();
    }

    event AllDelegated(address indexed vault, address indexed delegate, bytes32 rights, bool enable);

    function testDelegateAll(address vault, address delegate, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        // Create new harness
        harness = new Harness();
        // Calculate hash
        bytes32 hash = harness.exposed_computeDelegationHashForAll(delegate, rights, vault);
        // Hashes should not exist yet
        _checkHashes(vault, delegate, hash, false);
        // Storage should not exist yet
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        // Test correct event emitted
        vm.startPrank(vault);
        vm.expectEmit(true, true, true, true, address(harness));
        emit AllDelegated(vault, delegate, rights, enable);
        harness.delegateAll(delegate, rights, enable);
        vm.stopPrank();
        // Hashes should now exist regardless of true or false
        _checkHashes(vault, delegate, hash, true);
        // Check enable case
        if (enable) {
            // Check storage slots are written correctly
            _checkStorage(0, address(0), delegate, hash, rights, 0, vault);
            // Disable again
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit AllDelegated(vault, delegate, rights, false);
            harness.delegateAll(delegate, rights, false);
            vm.stopPrank();
            // There should be no change to the hash mappings
            _checkHashes(vault, delegate, hash, true);
        }
        // Check storage slots are written correctly for disable
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
    }

    event ContractDelegated(address indexed vault, address indexed delegate, address indexed contract_, bytes32 rights, bool enable);

    function testDelegateContract(address vault, address delegate, address contract_, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForContract(contract_, delegate, rights, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        vm.startPrank(vault);
        vm.expectEmit(true, true, true, true, address(harness));
        emit ContractDelegated(vault, delegate, contract_, rights, enable);
        harness.delegateContract(delegate, contract_, rights, enable);
        vm.stopPrank();
        _checkHashes(vault, delegate, hash, true);
        if (enable) {
            _checkStorage(0, contract_, delegate, hash, rights, 0, vault);
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit ContractDelegated(vault, delegate, contract_, rights, false);
            harness.delegateContract(delegate, contract_, rights, false);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
        }
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
    }

    event ERC721Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, bytes32 rights, bool enable);

    function testDelegateERC721(address vault, address delegate, address contract_, uint256 tokenId, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC721(contract_, delegate, rights, tokenId, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        vm.startPrank(vault);
        vm.expectEmit(true, true, true, true, address(harness));
        emit ERC721Delegated(vault, delegate, contract_, tokenId, rights, enable);
        harness.delegateERC721(delegate, contract_, tokenId, rights, enable);
        vm.stopPrank();
        _checkHashes(vault, delegate, hash, true);
        if (enable) {
            _checkStorage(0, contract_, delegate, hash, rights, tokenId, vault);
            vm.startPrank(vault);
            vm.expectEmit(true, true, true, true, address(harness));
            emit ERC721Delegated(vault, delegate, contract_, tokenId, rights, false);
            harness.delegateERC721(delegate, contract_, tokenId, rights, false);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
        }
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
    }

    event ERC20Delegated(address indexed vault, address indexed delegate, address indexed contract_, uint256 amount, bytes32 rights, bool enable);

    function testDelegateERC20(address vault, address delegate, address contract_, uint256 amount, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC20(contract_, delegate, rights, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        vm.startPrank(vault);
        vm.expectEmit(true, true, true, true, address(harness));
        emit ERC20Delegated(vault, delegate, contract_, amount, rights, enable);
        harness.delegateERC20(delegate, contract_, amount, rights, enable);
        vm.stopPrank();
        _checkHashes(vault, delegate, hash, true);
        if (enable) {
            _checkStorage(amount, contract_, delegate, hash, rights, 0, vault);
            vm.startPrank(vault);
            emit ERC20Delegated(vault, delegate, contract_, amount, rights, false);
            harness.delegateERC20(delegate, contract_, amount, rights, false);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
        }
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
    }

    event ERC1155Delegated(
        address indexed vault, address indexed delegate, address indexed contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable
    );

    function testDelegateERC1155(address vault, address delegate, address contract_, uint256 tokenId, uint256 amount, bytes32 rights, bool enable) public {
        vm.assume(vault > address(1));
        harness = new Harness();
        bytes32 hash = harness.exposed_computeDelegationHashForERC1155(contract_, delegate, rights, tokenId, vault);
        _checkHashes(vault, delegate, hash, false);
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(0));
        vm.startPrank(vault);
        vm.expectEmit(true, true, true, true, address(harness));
        emit ERC1155Delegated(vault, delegate, contract_, tokenId, amount, rights, enable);
        harness.delegateERC1155(delegate, contract_, tokenId, amount, rights, enable);
        vm.stopPrank();
        _checkHashes(vault, delegate, hash, true);
        if (enable) {
            _checkStorage(amount, contract_, delegate, hash, rights, tokenId, vault);
            vm.startPrank(vault);
            emit ERC1155Delegated(vault, delegate, contract_, tokenId, amount, rights, false);
            harness.delegateERC1155(delegate, contract_, tokenId, amount, rights, false);
            vm.stopPrank();
            _checkHashes(vault, delegate, hash, true);
        }
        _checkStorage(0, address(0), address(0), hash, 0, 0, address(1));
    }

    function _checkHashes(address vault, address delegate, bytes32 hash, bool on) internal {
        if (on) {
            assertEq(harness.exposed_vaultDelegationHashes(vault).length, 1);
            assertEq(harness.exposed_vaultDelegationHashes(vault)[0], hash);
            assertEq(harness.exposed_delegateDelegationHashes(delegate).length, 1);
            assertEq(harness.exposed_delegateDelegationHashes(delegate)[0], hash);
        } else {
            assertEq(harness.exposed_vaultDelegationHashes(vault).length, 0);
            assertEq(harness.exposed_delegateDelegationHashes(delegate).length, 0);
        }
    }

    function _checkStorage(uint256 amount, address contract_, address delegate, bytes32 hash, bytes32 rights, uint256 tokenId, address vault) internal {
        assertEq(harness.exposed_delegations(hash).length, uint256(type(StoragePositions).max) + 1);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.delegate)]))), delegate);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.vault)]))), vault);
        assertEq(harness.exposed_delegations(hash)[uint256(StoragePositions.rights)], rights);
        assertEq(address(uint160(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.contract_)]))), contract_);
        assertEq(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.tokenId)]), tokenId);
        assertEq(uint256(harness.exposed_delegations(hash)[uint256(StoragePositions.amount)]), amount);
    }
}

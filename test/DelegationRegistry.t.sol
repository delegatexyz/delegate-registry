// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

contract DelegateRegistryTest is Test {
    DelegateRegistry public reg;
    bytes32 public rights = "";

    function setUp() public {
        reg = new DelegateRegistry();
    }

    function getInitHash() public pure returns (bytes32) {
        bytes memory bytecode = type(DelegateRegistry).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }

    function testInitHash() public {
        bytes32 initHash = getInitHash();
        emit log_bytes32(initHash);
    }

    function testSupportsInterface(bytes32 seed) public {
        bytes4 falseInterfaceId = bytes4(seed & 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF);
        bytes4 interfaceId = type(IDelegateRegistry).interfaceId;
        if (falseInterfaceId == interfaceId) falseInterfaceId = bytes4(0);
        assertTrue(reg.supportsInterface(interfaceId));
        assertFalse(reg.supportsInterface(falseInterfaceId));
    }

    function testApproveAndRevokeForAll(address vault, address delegate, address contract_, uint256 tokenId) public {
        vm.assume(vault != address(0) && vault != address(1));
        // Approve
        vm.startPrank(vault);
        reg.delegateAll(delegate, rights, true);
        assertTrue(reg.checkDelegateForAll(delegate, vault, rights));
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_, rights));
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        // Revoke
        reg.delegateAll(delegate, rights, false);
        assertFalse(reg.checkDelegateForAll(delegate, vault, rights));
    }

    function testApproveAndRevokeForContract(address vault, address delegate, address contract_, uint256 tokenId) public {
        vm.assume(vault != address(0) && vault != address(1));
        // Approve
        vm.startPrank(vault);
        reg.delegateContract(delegate, contract_, rights, true);
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_, rights));
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, rights), type(uint256).max);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), type(uint256).max);
        // Revoke
        reg.delegateContract(delegate, contract_, rights, false);
        assertFalse(reg.checkDelegateForContract(delegate, vault, contract_, rights));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, address contract_, uint256 tokenId) public {
        vm.assume(vault != address(0) && vault != address(1));
        // Approve
        vm.startPrank(vault);
        reg.delegateERC721(delegate, contract_, tokenId, rights, true);
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
        // Revoke
        reg.delegateERC721(delegate, contract_, tokenId, rights, false);
        assertFalse(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, rights));
    }

    function testApproveAndRevokeForBalance(address vault, address delegate, address contract_, uint256 amount) public {
        vm.assume(vault != address(0) && vault != address(1));
        // Approve
        emit log_bytes(abi.encodePacked(amount, rights, delegate, vault, contract_));
        vm.startPrank(vault);
        reg.delegateERC20(delegate, contract_, amount, rights, true);
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, rights), amount);
        // Revoke
        reg.delegateERC20(delegate, contract_, amount, rights, false);
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, rights), 0);
    }

    function testApproveAndRevokeForTokenBalance(address vault, address delegate, address contract_, uint256 tokenId, uint256 amount) public {
        vm.assume(vault != address(0) && vault != address(1));
        // Approve
        vm.startPrank(vault);
        reg.delegateERC1155(delegate, contract_, tokenId, amount, rights, true);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), amount);
        // Revoke
        reg.delegateERC1155(delegate, contract_, tokenId, amount, rights, false);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, rights), 0);
    }

    function testMultipleDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1 && vault != address(0) && vault != address(1));
        vm.startPrank(vault);
        reg.delegateAll(delegate0, rights, true);
        reg.delegateAll(delegate1, rights, true);
        // Read
        IDelegateRegistry.Delegation[] memory info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 2);
        assertEq(info[0].vault, vault);
        assertEq(info[0].delegate, delegate0);
        assertEq(info[1].vault, vault);
        assertEq(info[1].delegate, delegate1);
        // Remove
        reg.delegateAll(delegate0, rights, false);
        info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 1);
    }

    function testBatchDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1 && vault != address(0) && vault != address(1));
        vm.startPrank(vault);
        IDelegateRegistry.BatchDelegation[] memory info = new IDelegateRegistry.BatchDelegation[](2);
        info[0] = IDelegateRegistry.BatchDelegation({
            type_: IDelegateRegistry.DelegationType.ALL,
            enable: true,
            delegate: delegate0,
            contract_: address(0),
            tokenId: 0,
            amount: 0,
            rights: ""
        });
        info[1] = IDelegateRegistry.BatchDelegation({
            type_: IDelegateRegistry.DelegationType.ALL,
            enable: true,
            delegate: delegate1,
            contract_: address(0),
            tokenId: 0,
            amount: 0,
            rights: ""
        });
        reg.batchDelegate(info);

        IDelegateRegistry.Delegation[] memory delegations = reg.getDelegationsForVault(vault);
        assertEq(delegations.length, 2);
        assertEq(delegations[0].vault, vault);
        assertEq(delegations[1].vault, vault);
        assertEq(delegations[0].delegate, delegate0);
        assertEq(delegations[1].delegate, delegate1);
        assertTrue(delegations[0].type_ == IDelegateRegistry.DelegationType.ALL);
        assertTrue(delegations[1].type_ == IDelegateRegistry.DelegationType.ALL);
    }

    function testDelegateEnumeration(
        address vault0,
        address vault1,
        address delegate0,
        address delegate1,
        address contract0,
        address contract1,
        uint256 tokenId0,
        uint256 tokenId1,
        uint256 amount0,
        uint256 amount1
    ) public {
        vm.assume(vault0 != address(0) && vault1 != address(0) && vault0 != address(1) && vault1 != address(1));
        vm.assume(vault0 != vault1 && vault0 != delegate0 && vault0 != delegate1);
        vm.assume(vault1 != delegate0 && vault1 != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != address(0) && contract1 != address(0) && contract0 != contract1);
        vm.assume(tokenId0 != 0 && tokenId1 != 0 && tokenId0 != tokenId1);
        vm.assume(amount0 != 0 && amount1 != 0 && amount0 != amount1);

        // vault0 delegates all five tiers to delegate0, and all five giv to delegate1
        vm.startPrank(vault0);
        reg.delegateAll(delegate0, rights, true);
        reg.delegateContract(delegate0, contract0, rights, true);
        reg.delegateERC721(delegate0, contract0, tokenId0, rights, true);
        reg.delegateERC20(delegate0, contract0, amount0, rights, true);
        reg.delegateERC1155(delegate0, contract0, tokenId0, amount0, rights, true);
        reg.delegateAll(delegate1, rights, true);
        reg.delegateContract(delegate1, contract1, rights, true);
        reg.delegateERC721(delegate1, contract1, tokenId1, rights, true);
        reg.delegateERC20(delegate1, contract1, amount1, rights, true);
        reg.delegateERC1155(delegate1, contract1, tokenId1, amount1, rights, true);

        // vault1 delegates all five tiers to delegate0
        changePrank(vault1);
        reg.delegateAll(delegate0, rights, true);
        reg.delegateContract(delegate0, contract0, rights, true);
        reg.delegateERC721(delegate0, contract0, tokenId0, rights, true);
        reg.delegateERC20(delegate0, contract0, amount0, rights, true);
        reg.delegateERC1155(delegate0, contract0, tokenId0, amount0, rights, true);

        // vault0 revokes all three tiers for delegate0, check incremental decrease in delegate enumerations
        changePrank(vault0);
        // check six in total, three from vault0 and three from vault1
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 10);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 10);
        reg.delegateAll(delegate0, rights, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 9);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 9);
        reg.delegateContract(delegate0, contract0, rights, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 8);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 8);
        reg.delegateERC721(delegate0, contract0, tokenId0, rights, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 7);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 7);
        reg.delegateERC20(delegate0, contract0, amount0, rights, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 6);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 6);
        reg.delegateERC1155(delegate0, contract0, tokenId0, amount0, rights, false);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 5);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 5);

        // vault0 re-delegates to delegate0
        changePrank(vault0);
        reg.delegateAll(delegate0, rights, true);
        reg.delegateContract(delegate0, contract0, rights, true);
        reg.delegateERC721(delegate0, contract0, tokenId0, rights, true);
        reg.delegateERC20(delegate0, contract0, amount0, rights, true);
        reg.delegateERC1155(delegate0, contract0, tokenId0, amount0, rights, true);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 10);
        assertEq(reg.getDelegationsForDelegate(delegate1).length, 5);
        assertEq(reg.getDelegationHashesForDelegate(delegate0).length, 10);
        assertEq(reg.getDelegationHashesForDelegate(delegate1).length, 5);
    }

    function testVaultEnumerations(address vault, address delegate0, address delegate1, address contract0, address contract1, uint256 tokenId, uint256 amount)
        public
    {
        vm.assume(vault != address(0) && vault != address(1));
        vm.assume(vault != delegate0 && vault != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != contract1);
        vm.startPrank(vault);
        reg.delegateAll(delegate0, rights, true);
        reg.delegateContract(delegate0, contract0, rights, true);
        reg.delegateERC721(delegate0, contract1, tokenId, rights, true);
        reg.delegateERC20(delegate0, contract1, amount, rights, true);
        reg.delegateAll(delegate1, rights, true);
        reg.delegateContract(delegate1, contract0, rights, true);

        // Read
        IDelegateRegistry.Delegation[] memory vaultDelegations;
        vaultDelegations = reg.getDelegationsForVault(vault);
        assertEq(vaultDelegations.length, 6);
        assertTrue(vaultDelegations[1].type_ == IDelegateRegistry.DelegationType.CONTRACT);
    }

    function _createUniqueDelegations(uint256 start, uint256 stop) internal {
        for (uint256 i = start; i < stop; i++) {
            address delegate = address(bytes20(keccak256(abi.encode("delegate", i))));
            address contract_ = address(bytes20(keccak256(abi.encode("contract", i))));
            uint256 amount = uint256(keccak256(abi.encode("amount", i)));
            uint256 tokenId = uint256(keccak256(abi.encode("tokenId", i)));
            reg.delegateAll(delegate, rights, true);
            reg.delegateContract(delegate, contract_, rights, true);
            reg.delegateERC20(delegate, contract_, amount, rights, true);
            reg.delegateERC721(delegate, contract_, tokenId, rights, true);
            reg.delegateERC1155(delegate, contract_, tokenId, amount, rights, true);
        }
    }

    function testGetDelegationsGas() public {
        uint256 delegationsLimit = 2600; // Actual limit is x5
        _createUniqueDelegations(0, delegationsLimit);
        IDelegateRegistry.Delegation[] memory vaultDelegations = reg.getDelegationsForVault(address(this));
        assertEq(vaultDelegations.length, 5 * delegationsLimit);
    }

    function testGetDelegationHashesGas() public {
        uint256 hashesLimit = 20800; // Actual limit is x5
        _createUniqueDelegations(0, hashesLimit);
        bytes32[] memory vaultDelegationHashes = reg.getDelegationHashesForVault(address(this));
        assertEq(vaultDelegationHashes.length, 5 * hashesLimit);
    }
}

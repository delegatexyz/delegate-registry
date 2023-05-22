// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegateRegistry} from "src/DelegateRegistry.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

contract DelegateRegistryTest is Test {
    DelegateRegistry reg;
    bytes32 data = bytes32(0x0);

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

    function testApproveAndRevokeForAll(address vault, address delegate, address contract_, uint256 tokenId, bytes32 data_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForAll(delegate, true, data_);
        assertTrue(reg.checkDelegateForAll(delegate, vault, data_));
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_, data_));
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, data_));
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, data_), type(uint256).max);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, 0, data_), type(uint256).max);
        // Revoke
        reg.delegateForAll(delegate, false, data_);
        assertFalse(reg.checkDelegateForAll(delegate, vault, data_));
    }

    function testApproveAndRevokeForContract(address vault, address delegate, address contract_, uint256 tokenId, bytes32 data_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForContract(delegate, contract_, true, data_);
        assertTrue(reg.checkDelegateForContract(delegate, vault, contract_, data_));
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, data_));
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, data_), type(uint256).max);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, data_), type(uint256).max);
        // Revoke
        reg.delegateForContract(delegate, contract_, false, data_);
        assertFalse(reg.checkDelegateForContract(delegate, vault, contract_, data_));
    }

    function testApproveAndRevokeForToken(address vault, address delegate, address contract_, uint256 tokenId) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForERC721(delegate, contract_, tokenId, true, data);
        assertTrue(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, data));
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, data), type(uint256).max);
        // Revoke
        reg.delegateForERC721(delegate, contract_, tokenId, false, data);
        assertFalse(reg.checkDelegateForERC721(delegate, vault, contract_, tokenId, data));
    }

    function testApproveAndRevokeForBalance(address vault, address delegate, address contract_, uint256 balance, bytes32 data_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForERC20(delegate, contract_, balance, true, data_);
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, data_), balance);
        // Revoke
        reg.delegateForERC20(delegate, contract_, balance, false, data_);
        assertEq(reg.checkDelegateForERC20(delegate, vault, contract_, data_), 0);
    }

    function testApproveAndRevokeForTokenBalance(address vault, address delegate, address contract_, uint256 tokenId, uint256 balance, bytes32 data_) public {
        // Approve
        vm.startPrank(vault);
        reg.delegateForERC1155(delegate, contract_, tokenId, balance, true, data_);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, data_), balance);
        // Revoke
        reg.delegateForERC1155(delegate, contract_, tokenId, balance, false, data_);
        assertEq(reg.checkDelegateForERC1155(delegate, vault, contract_, tokenId, data_), 0);
    }

    function testMultipleDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true, data);
        reg.delegateForAll(delegate1, true, data);
        // Read
        IDelegateRegistry.DelegationInfo[] memory info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 2);
        assertEq(info[0].vault, vault);
        assertEq(info[0].delegate, delegate0);
        assertEq(info[1].vault, vault);
        assertEq(info[1].delegate, delegate1);
        // Remove
        reg.delegateForAll(delegate0, false, data);
        info = reg.getDelegationsForVault(vault);
        assertEq(info.length, 1);
    }

    function testBatchDelegationForAll(address vault, address delegate0, address delegate1) public {
        vm.assume(delegate0 != delegate1);
        vm.startPrank(vault);
        IDelegateRegistry.DelegationInfo[] memory info = new IDelegateRegistry.DelegationInfo[](2);
        info[0] = IDelegateRegistry.DelegationInfo({
            type_: IDelegateRegistry.DelegationType.ALL,
            vault: vault,
            delegate: delegate0,
            contract_: address(0),
            tokenId: 0,
            balance: 0,
            data: data
        });
        info[1] = IDelegateRegistry.DelegationInfo({
            type_: IDelegateRegistry.DelegationType.ALL,
            vault: vault,
            delegate: delegate1,
            contract_: address(0),
            tokenId: 0,
            balance: 0,
            data: data
        });
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[1] = true;
        reg.batchDelegate(info, values);

        IDelegateRegistry.DelegationInfo[] memory delegations = reg.getDelegationsForVault(vault);
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
        uint256 balance0,
        uint256 balance1
    ) public {
        vm.assume(vault0 != vault1 && vault0 != delegate0 && vault0 != delegate1);
        vm.assume(vault1 != delegate0 && vault1 != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != address(0) && contract1 != address(0) && contract0 != contract1);
        vm.assume(tokenId0 != 0 && tokenId1 != 0 && tokenId0 != tokenId1);
        vm.assume(balance0 != 0 && balance1 != 0 && balance0 != balance1);

        // vault0 delegates all five tiers to delegate0, and all five giv to delegate1
        vm.startPrank(vault0);
        reg.delegateForAll(delegate0, true, data);
        reg.delegateForContract(delegate0, contract0, true, data);
        reg.delegateForERC721(delegate0, contract0, tokenId0, true, data);
        reg.delegateForERC20(delegate0, contract0, balance0, true, data);
        reg.delegateForERC1155(delegate0, contract0, tokenId0, balance0, true, data);
        reg.delegateForAll(delegate1, true, data);
        reg.delegateForContract(delegate1, contract1, true, data);
        reg.delegateForERC721(delegate1, contract1, tokenId1, true, data);
        reg.delegateForERC20(delegate1, contract1, balance1, true, data);
        reg.delegateForERC1155(delegate1, contract1, tokenId1, balance1, true, data);

        // vault1 delegates all five tiers to delegate0
        changePrank(vault1);
        reg.delegateForAll(delegate0, true, data);
        reg.delegateForContract(delegate0, contract0, true, data);
        reg.delegateForERC721(delegate0, contract0, tokenId0, true, data);
        reg.delegateForERC20(delegate0, contract0, balance0, true, data);
        reg.delegateForERC1155(delegate0, contract0, tokenId0, balance0, true, data);

        // vault0 revokes all three tiers for delegate0, check incremental decrease in delegate enumerations
        changePrank(vault0);
        // check six in total, three from vault0 and three from vault1
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 10);
        reg.delegateForAll(delegate0, false, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 9);
        reg.delegateForContract(delegate0, contract0, false, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 8);
        reg.delegateForERC721(delegate0, contract0, tokenId0, false, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 7);
        reg.delegateForERC20(delegate0, contract0, balance0, false, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 6);
        reg.delegateForERC1155(delegate0, contract0, tokenId0, balance0, false, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 5);

        // vault0 re-delegates to delegate0
        changePrank(vault0);
        reg.delegateForAll(delegate0, true, data);
        reg.delegateForContract(delegate0, contract0, true, data);
        reg.delegateForERC721(delegate0, contract0, tokenId0, true, data);
        reg.delegateForERC20(delegate0, contract0, balance0, true, data);
        reg.delegateForERC1155(delegate0, contract0, tokenId0, balance0, true, data);
        assertEq(reg.getDelegationsForDelegate(delegate0).length, 10);
        assertEq(reg.getDelegationsForDelegate(delegate1).length, 5);
    }

    function testVaultEnumerations(address vault, address delegate0, address delegate1, address contract0, address contract1, uint256 tokenId, uint256 balance)
        public
    {
        vm.assume(vault != delegate0 && vault != delegate1);
        vm.assume(delegate0 != delegate1);
        vm.assume(contract0 != contract1);
        vm.startPrank(vault);
        reg.delegateForAll(delegate0, true, data);
        reg.delegateForContract(delegate0, contract0, true, data);
        reg.delegateForERC721(delegate0, contract1, tokenId, true, data);
        reg.delegateForERC20(delegate0, contract1, balance, true, data);
        reg.delegateForAll(delegate1, true, data);
        reg.delegateForContract(delegate1, contract0, true, data);

        // Read
        IDelegateRegistry.DelegationInfo[] memory vaultDelegations;
        vaultDelegations = reg.getDelegationsForVault(vault);
        assertEq(vaultDelegations.length, 6);
        assertTrue(vaultDelegations[1].type_ == IDelegateRegistry.DelegationType.CONTRACT);
    }
}
